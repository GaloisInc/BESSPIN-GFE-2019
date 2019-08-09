#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <getopt.h>
#include <string.h>
#include <libgen.h>
#include <dirent.h>
#include <time.h>
#include <stdbool.h>
#include <ctype.h>
#include "clocking.h"

#include "../drivers/bluenoc.h"

/* Bluespec's Board ID list */
typedef struct {
  unsigned short device_id;
  bool           variable_clocking;
  char           buildname[32];
  char           description[256];
} tBlueNoCBoard;


static tBlueNoCBoard board_id_table[] = {
  //  { 0xB101, true,  "dn10ghxtll", "Dini DNPCIe_10G_HXT_LL" },
  { 0xB107, true,  "dn10gk7ll",  "Dini DNPCIe_10G_K7_LL[_QSFP]" },
  { 0xB706, false, "dn7406",     "Dini DN7006K10PCIe-8T" },
  { 0xB746, false, "dn7006",     "Dini DN7406K10PCIe-8T" },
  { 0xB72A, true,  "dnv7f2a",    "Dini DNV7F2A" },
  { 0xB84A, true,  "dnvuf4a",    "Dini DNVUF4A" },
  { 0xE72A, false, "rpp2",       "Cadence RPPII" },
  { 0xE84A, false, "klvuf4a",    "Cadence S1" },
  { 0xC200, true,  "dh2000tq",   "HyperSilicon VeriTiger-DH2000TQ" },
  { 0xC2B5, true,  "b2000t",     "HyperSilicon HyperHPC-B2000T" },
  { 0xD720, true,  "pdv72kr2",   "ProDesign FM-XC7V2000T-R2" },
  { 0xA605, true,  "ml605",      "Xilinx ML605" },
  { 0xA705, true,  "kc705",      "Xilinx KC705" },
  { 0xA707, true,  "vc707",      "Xilinx VC707" },
  { 0xA709, true,  "vc709",      "Xilinx VC709" },
  { 0xA805, true,  "kcu105",     "Xilinx KCU105" },
  { 0xA808, true,  "vcu108",     "Xilinx VCU108" },
  { 0xA118, true,  "vcu118",     "Xilinx VCU118" },
  { 0xFA10, false, "arria10gx",  "Intel Arria 10 GX" },
  { 0, 0 },
};


static void print_usage(const char* argv0)
{
  char* argv0_copy = strdup(argv0);
  char* pgm = basename(argv0_copy);

  printf("Usage: %s help\n", pgm);
  printf("       %s info    [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s build   [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s reset   [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s down    [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s up      [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s board   [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s status  [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s clock   <MHz>               [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s debug   ([+-]<debug_mode>)* [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s profile <profile_command>   [ <file1> [ .. <fileN> ] ]\n", pgm);
  printf("       %s boards\n", pgm);
  printf("\n");
  printf("Modes:\n");
  printf("  help    - Print usage information and exit.\n");
  printf("  info    - Describe the BlueNoC target(s).\n");
  printf("  build   - Display the Build number.\n");
  printf("  reset   - Reset the BlueNoC target(s).\n");
  printf("  down    - Deactivate the BlueNoC target(s).\n");
  printf("  up      - Reactivate the BlueNoC target(s).\n");
  printf("  board   - Identify the BlueNoC board.\n");
  printf("  status  - Print the current board connection status.\n");
  printf("  clock   - Set the SceMi clock rate (2x the fastest control clock).\n");
  printf("  debug   - Control debugging output written to the kernel log.\n");
  printf("  profile - Start and stop profiling BlueNoC driver activity.\n");
  printf("  boards  - List all boards supported by build infrastructure.\n");
  printf("\n");
  printf("File arguments:\n");
  printf("  <file> - Operate only on the named file.\n");
  printf("\n");
  printf("Multiple files can be supplied as arguments.\n");
  printf("If no file argument is supplied, the tool will search for BlueNoC\n");
  printf("targets and operate on all of them it finds.\n");
  printf("\n");
  printf("If no mode is specified, it defaults to 'info', so the command\n");
  printf("'%s' by itself is equivalent to '%s info' (it will search out\n", pgm, pgm);
  printf("and describe all BlueNoC targets).");
  printf("\n");
  printf("Debug modes:\n");
  printf("  calls   - Log driver function calls for reading and writing.\n");
  printf("  data    - Log all data read and written across the BlueNoC link.\n");
  printf("  dma     - Log DMA command activity.\n");
  printf("  intrs   - Log interrupts.\n");
  printf("  off     - Turn off all debugging.\n");
  printf("  on      - Turn on all debugging.\n");
  printf("Multiple non-off modes can be specified on the same command line.\n");
  printf("A mode can be prefixed with '-' to turn it off. If it is prefixed\n");
  printf("with a '+' or has no prefix, it will be turned on. Prefixes should\n");
  printf("not be used with the 'off' and 'on' modes.\n");
  printf("\n");
  printf("Profiling commands:\n");
  printf("  start   - Begin collecting profiling data.\n");
  printf("  stop    - Stop collecting profiling data and write accumulated data\n");
  printf("            to the kernel log.\n");
  printf("\n");

  free(argv0_copy);
}

typedef enum { HELP, INFO, BUILD, BOARD, RESET, DOWN, UP, DEBUG, PROFILE, STATUS, CLOCK, BOARDS } tMode;

static int is_bluenoc_file(const struct dirent* ent)
{
  // match "bluenoc_" followed by a non-zero number of digits
  if (strncmp(ent->d_name,"bluenoc_",8) == 0) {
    const char *p0 = (ent->d_name) + 8;
    const char *p = p0;
    while (isdigit(*p)) { p += 1; }
    return ((*p == '\0') && (p != p0));
  }
  else
    return 0;
}

static void print_debug_mode(tDebugLevel dbg_level)
{
  if (dbg_level == DEBUG_OFF)  printf(" OFF");
  if (dbg_level & DEBUG_CALLS) printf(" CALLS");
  if (dbg_level & DEBUG_DATA)  printf(" DATA");
  if (dbg_level & DEBUG_DMA)   printf(" DMA");
  if (dbg_level & DEBUG_INTR)  printf(" INTR");
}

static void print_profile_mode(tDebugLevel dbg_level)
{
  if (dbg_level & DEBUG_PROFILE)
    printf(" ON");
  else
    printf(" OFF");
}

static tBlueNoCBoard get_board_id(bool show, unsigned int vendor_id, unsigned int device_id)
{
  int i;

  for(i = 0; i < sizeof(board_id_table)/(sizeof(tBlueNoCBoard)); ++i) {
    //printf("board_id_table[%d] = %x %s\n", i, board_id_table[i].device_id, board_id_table[i].description);
    if (board_id_table[i].device_id == 0) {
      if (show) printf("  Board:            Unknown or Unidentified Board\n");
    } else if (board_id_table[i].device_id == device_id) {
      if (show) printf("  Board:            %s (%04X)\n", board_id_table[i].description, board_id_table[i].device_id);
      break;
    }
  }
  return board_id_table[i];
}


// Return values:
//    1  Command succeeded
//    0  Command is valid, but no action taken
//   -1  Command failed (Error)
//   -2  Device is not an accessible board (reported as -1 if 'strict' is true)
//
static int process(const char* file, tMode mode, unsigned int strict, tDebugLevel turn_off, tDebugLevel turn_on, double freqMHz)
{
  int ret = 0;
  tBoardInfo board_info;
  int res;
  int fd = open(file,O_RDONLY);

  if (fd == -1) {
    if (strict) {
      perror(file);
      return -1;
    }
    return -2;
  }

  res = ioctl(fd,BNOC_IDENTIFY,&board_info);
  if (res == -1) {
    if (strict) {
      perror("identify ioctl");
      ret = -1;
    } else {
      ret = -2;
    }
    goto exit_process;
  }

  switch (mode) {
    case INFO: {
      printf("Found BlueNoC device at %s\n", file);
      printf("  Board number:     %d\n", board_info.board_number);
      if (board_info.is_active) {
        time_t t = board_info.timestamp;
	tBlueNoCBoard board = get_board_id(true, board_info.subvendor_id, board_info.subdevice_id);
        printf("  BlueNoC revision: %d.%d\n", board_info.major_rev, board_info.minor_rev);
        printf("  Build number:     %d\n", board_info.build);
        printf("  Timestamp:        %s", ctime(&t));
	unsigned long status;
	bool has_status = false;
	bool has_clkctrl = false;
	res = ioctl(fd,BNOC_CAPABILITIES,&status);
	if ((status != -1) && (res != -1)) {
	  has_status = status & 0x1;
	  has_clkctrl = status & 0x2;
	}
	if (board.variable_clocking && has_clkctrl) {
	  ClockGenerator c(fd);
	  unsigned long rate = c.GetRate();
	  if (rate != 0) {
	    printf("  SceMi Clock:      %3.2f MHz\n", (double)(rate/1000000.0));
	  }
	}
        printf("  Network width:    %d bytes per beat\n", board_info.bytes_per_beat);
        printf("  Content ID:       %llx\n", board_info.content_id);
        tDebugLevel dbg_level = DEBUG_OFF;
        res = ioctl(fd,BNOC_GET_DEBUG_LEVEL,&dbg_level);
        if (res == -1) {
          perror("debug level query ioctl");
        } else {
          printf("  Debug level:     ");
          print_debug_mode(dbg_level);
          printf("\n");
          printf("  Profiling:       ");
          print_profile_mode(dbg_level);
          printf("\n");
        }
	if (has_status) {
	  res = ioctl(fd,BNOC_GET_STATUS,&status);
	  if (res == -1) {
	    perror("status query ioctl");
	  } else {
	    bool pcie_link = (status & 0x1) && (status != 0xFFFFFFFF);
	    bool bnoc_link = (status & 0x2) && (status != 0xFFFFFFFF);
	    bool intr_on   = (status & 0x4) && (status != 0xFFFFFFFF);
	    bool mem_en    = (status & 0x8) && (status != 0xFFFFFFFF);
	    bool out_rst   = (status & 0x10) && (status != 0xFFFFFFFF);

	    printf("  PCIe Link:        %s\n", ((pcie_link) ? "ENABLED" : "DISABLED"));
	    printf("  BlueNoC Link:     %s\n", ((bnoc_link) ? "ENABLED" : "DISABLED"));
	    printf("  BlueNoC I/F:      %s\n", ((intr_on && out_rst) ? "READY" : "NOT READY"));
	    printf("  Memory Sub-Sys:   %s\n", ((mem_en) ? "ENABLED" : "DISABLED"));
	  }
	}
      } else {
        printf("  *** BOARD IS DEACTIVATED ***\n");
      }
      ret = 1;
      break;
    }
    case BUILD: {
      if (board_info.is_active) {
        time_t t = board_info.timestamp;
        printf("%d\n", board_info.build);
      }
      ret = 1;
      break;
    }
    case BOARD: {
      if (board_info.is_active) {
	for(int i = 0; i < sizeof(board_id_table)/(sizeof(tBlueNoCBoard)); ++i) {
	  if (board_id_table[i].device_id == board_info.subdevice_id) {
	    printf("%s\n", board_id_table[i].buildname);
	    break;
	  }
	}
      }
      ret = 1;
      break;
    }
    case BOARDS: {
      for(int i = 0; i < sizeof(board_id_table)/(sizeof(tBlueNoCBoard)); ++i) {
	if (board_id_table[i].buildname[0] != 0) {
	  printf("%-12s - %s\n", board_id_table[i].buildname, board_id_table[i].description);
	}
      }
      ret = 1;
      break;
    }
    case RESET: {
      if (!board_info.is_active) {
        printf("Cannot reset BlueNoC device at %s because it is deactivated\n", file);
      } else {
        res = ioctl(fd,BNOC_SOFT_RESET);
        if (res == -1) {
          perror("reset ioctl");
          ret = -1;
        } else {
          printf("Reset BlueNoC device at %s\n", file);
          ret = 1;
        }
      }
      break;
    }
    case DOWN: {
      if (!board_info.is_active) {
        printf("BlueNoC device at %s is already deactivated\n", file);
      } else {
        res = ioctl(fd,BNOC_DEACTIVATE);
        if (res == -1) {
          perror("deactivate ioctl");
          ret = -1;
        } else {
          printf("Deactivated BlueNoC device at %s\n", file);
          ret = 1;
        }
      }
      break;
    }
    case UP: {
      if (board_info.is_active) {
        printf("BlueNoC device at %s is already activated\n", file);
      } else {
        res = ioctl(fd,BNOC_REACTIVATE);
        if (res == -1) {
          perror("reactivate ioctl");
          ret = -1;
        } else {
          printf("Reactivated BlueNoC device at %s\n", file);
          ret = 1;
        }
      }
      break;
    }
    case CLOCK: {
      ClockGenerator c(fd);
      unsigned long rate = c.GetRate();
      printf("Current Rate: %3.2f MHz\n", (double)(rate/1000000.0));
      if (freqMHz > 0.0) {
	printf("Setting Rate: %3.2f MHz\n", freqMHz);
	c.SetRate((unsigned long)(freqMHz*1000000));
	sleep(1);
	if (c.IsLocked()) {
	  //printf("Locked!\n");
	  rate = c.GetRate();
	  printf("Current Rate: %3.2f MHz\n", (double)(rate/1000000.0));
	  ret = 1;
	} else {
	  printf("Failed to set clock rate\n");
	  ret = -1;
	}
      } else {
	ret = 1;
      }
      break;
    }
    case DEBUG: /* fall through */
    case PROFILE: {
      tDebugLevel dbg_level = DEBUG_OFF;
      res = ioctl(fd,BNOC_GET_DEBUG_LEVEL,&dbg_level);
      if (res == -1) {
        perror("debug level query ioctl");
        ret = -1;
      } else if (!(turn_on | turn_off)) {
        /* no changes, just report current status */
        printf("BlueNoC device at %s %s mode is:", file, (mode == DEBUG) ? "debug" : "profile");
        if (mode == DEBUG)
          print_debug_mode(dbg_level);
        else
          print_profile_mode(dbg_level);
        printf("\n");
      } else {
        dbg_level &= ~turn_off;
        dbg_level |= turn_on;
        res = ioctl(fd,BNOC_SET_DEBUG_LEVEL,&dbg_level);
        if (res == -1) {
          perror("debug level update ioctl");
          ret = -1;
        } else {
          printf("BlueNoC device at %s %s mode is now:", file, (mode == DEBUG) ? "debug" : "profiling");
          if (mode == DEBUG)
            print_debug_mode(dbg_level);
          else
            print_profile_mode(dbg_level);
          printf("\n");
          ret = 1;
        }
      }
      break;
    }
    case STATUS: {
      unsigned int status;
      if (board_info.is_active) {
	res = ioctl(fd,BNOC_GET_STATUS,&status);
	if (res == -1) {
	  perror("status query ioctl");
	  ret = -1;
	} else {
	  bool pcie_link = (status & 0x1) && (status != 0xFFFFFFFF);
	  bool bnoc_link = (status & 0x2) && (status != 0xFFFFFFFF);
	  bool intr_on   = (status & 0x4) && (status != 0xFFFFFFFF);
	  bool mem_en    = (status & 0x8) && (status != 0xFFFFFFFF);
	  bool out_rst   = (status & 0x10) && (status != 0xFFFFFFFF);

	  printf("%d\n", status);
	  ret = 1;
	}
      } else {
	printf("0\n");
	ret = -1;
      }
      break;
    }
  }

 exit_process:
  close(fd);
  return ret;
}

int main(int argc, char* const argv[])
{
  int opt;
  unsigned int n;
  tMode mode;
  int ret;
  int process_failed;
  tDebugLevel turn_on = 0;
  tDebugLevel turn_off = 0;
  double freqMHz = 0.0;

  while (1) {
    opt = getopt(argc, argv, "+h");
    if (opt == -1) break;
    else if ((opt == '?') || (opt == ':') || (opt == 'h')) {
      print_usage(argv[0]);
      exit(opt == 'h' ? 0 : 1);
    }
  };

  /* determine the execution mode */
  if (optind == argc) {
    mode = INFO; /* no argument -- implies INFO */
  } else if (strcmp("help",argv[optind]) == 0) {
    mode = HELP;
  } else if (strcmp("info",argv[optind]) == 0) {
    mode = INFO;
    optind += 1;
  } else if (strcmp("build",argv[optind]) == 0) {
    mode = BUILD;
    optind += 1;
  } else if (strcmp("boards",argv[optind]) == 0) {
    mode = BOARDS;
    optind += 1;
  } else if (strcmp("board",argv[optind]) == 0) {
    mode = BOARD;
    optind += 1;
  } else if (strcmp("status",argv[optind]) == 0) {
    mode = STATUS;
    optind += 1;
  } else if (strcmp("reset",argv[optind]) == 0) {
    mode = RESET;
    optind += 1;
  } else if (strcmp("down",argv[optind]) == 0) {
    mode = DOWN;
    optind += 1;
  } else if (strcmp("up",argv[optind]) == 0) {
    mode = UP;
    optind += 1;
  } else if (strcmp("debug",argv[optind]) == 0) {
    mode = DEBUG;
    optind += 1;
    while (optind < argc) {
      char* ptr = argv[optind];
      int do_remove = 0;
      if (*ptr == '-') {
        do_remove = 1;
        ++ptr;
      } else if (*ptr == '+') {
        ++ptr;
      }
      if ((strcmp("call",ptr) == 0) || (strcmp("calls",ptr) == 0)) {
        if (do_remove)
          turn_off |= DEBUG_CALLS;
        else
          turn_on |= DEBUG_CALLS;
        optind += 1;
      } else if (strcmp("data",ptr) == 0) {
        if (do_remove)
          turn_off |= DEBUG_DATA;
        else
          turn_on |= DEBUG_DATA;
        optind += 1;
      } else if (strcmp("dma",ptr) == 0) {
        if (do_remove)
          turn_off |= DEBUG_DMA;
        else
          turn_on |= DEBUG_DMA;
        optind += 1;
      } else if ((strcmp("intr",ptr) == 0) || (strcmp("intrs",ptr) == 0)) {
        if (do_remove)
          turn_off |= DEBUG_INTR;
        else
          turn_on |= DEBUG_INTR;
        optind += 1;
      } else if (strcmp("off",ptr) == 0) {
        if (do_remove) {
          printf("Error: '-off' is not a valid debug mode.\n");
          print_usage(argv[0]);
          exit(1);
        } else {
          turn_off |= DEBUG_CALLS | DEBUG_DATA | DEBUG_DMA | DEBUG_INTR;
        }
        optind += 1;
      } else if (strcmp("on",ptr) == 0) {
        if (do_remove) {
          printf("Error: '-on' is not a valid debug mode. Did you mean 'off'?\n");
          print_usage(argv[0]);
          exit(1);
        } else {
          turn_on |= DEBUG_CALLS | DEBUG_DATA | DEBUG_DMA | DEBUG_INTR;
        }
        optind += 1;
      } else {
        /* not a valid debug mode, assume it is the start of file names */
        break;
      }
    }
    if (turn_off & turn_on) {
      printf("Error: inconsistent debug modes specified.\n");
      print_usage(argv[0]);
      exit(1);
    }
  } else if (  (strcmp("prof",argv[optind]) == 0)
            || (strcmp("profile",argv[optind]) == 0)
            ) {
    mode = PROFILE;
    optind += 1;
    if (optind < argc) {
      if ((strcmp("start",argv[optind]) == 0) || (strcmp("on",argv[optind]) == 0)) {
        turn_on |= DEBUG_PROFILE;
        optind += 1;
      } else if ((strcmp("stop",argv[optind]) == 0) || (strcmp("off",argv[optind]) == 0)) {
        turn_off |= DEBUG_PROFILE;
        optind += 1;
      } else {
        /* not a valid profile command, assume it is the start of file names */
      }
    }
    if (turn_off & turn_on) {
      printf("Error: conflicting profile commands specified.\n");
      print_usage(argv[0]);
      exit(1);
    }
  } else if (strcmp("clock",argv[optind]) == 0) {
    mode = CLOCK;
    optind += 1;
    if (optind < argc) {
      freqMHz = atof(argv[optind]);
      optind += 1;
    }
  } else {
    /* not a recognized mode, assume it is a file name, and use INFO mode */
    mode = INFO;
  }

  /* execute the requested action */

  if (mode == HELP) {
    print_usage(argv[0]);
    exit(0);
  }

  process_failed = 0;
  if (optind == argc) {
    /* no file arguments given, so look for all /dev/bluenoc_* */
    struct dirent **eps;
    int res;

    res = scandir ("/dev", &eps, is_bluenoc_file, alphasort);
    if (res < 0) {
      perror("Couldn't open the /dev directory");
      exit(1);
    }
    else if (res == 0) {
      printf("No BlueNoC targets found.\n");
    }
    else {
      int cnt;
      char* filename = NULL;
      unsigned int len = 0;
      int board_found = 0;
      for (cnt = 0; cnt < res; ++cnt)
      {
        unsigned int l = 6 + strlen(eps[cnt]->d_name);
        if (l > len) {
          if (filename != NULL) free(filename);
          filename = (char*) malloc(l);
          if (filename == NULL) {
            perror("Failed to allocate file name memory");
            exit(1);
          }
          len = l;
        }
        strcpy(filename, "/dev/");
        strcpy(filename+5, eps[cnt]->d_name);
	int process_res = process(filename,mode,0,turn_off,turn_on,freqMHz);
	if (process_res != -2) {
	  board_found = 1;
	  process_failed |= (process_res == -1);
	} else {
	  // printf("Ignoring: %s\n", filename);
	}
      }
      if (filename != NULL) free(filename);
      if (! board_found) {
	printf("No BlueNoC targets found.\n");
      }
    }
  }
  else {
    /* only operate on the given file arguments */
    for (n = optind; n < argc; ++n)
      process_failed |= (process(argv[n],mode,1,turn_off,turn_on,freqMHz) == -1);
  }

  exit(process_failed ? 1 : 0);
}
