
#include <assert.h>
#include <errno.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/socket.h>

// #define DEBUG

#ifdef DEBUG
#define DEBUG_PRINTF(...)  fprintf(stderr, __VA_ARGS__)
#else
#define DEBUG_PRINTF(...)
#endif

#define BUF_SIZE                512

#define CMD_RESET               0
#define CMD_TMS_SEQ             1
#define CMD_SCAN_CHAIN          2
#define CMD_SCAN_CHAIN_FLIP_TMS 3
#define CMD_STOP_SIMU           4

#ifdef __cplusplus
extern "C" {
#endif

struct vpi_cmd {
    int cmd;
    unsigned char buffer_out[BUF_SIZE];
    unsigned char buffer_in[BUF_SIZE];
    int length;
    int nb_bits;
};

typedef enum {
    TEST_LOGIC_RESET,
    RUN_TEST_IDLE,
    SELECT_DR_SCAN,
    CAPTURE_DR,
    SHIFT_DR,
    EXIT1_DR,
    PAUSE_DR,
    EXIT2_DR,
    UPDATE_DR,
    SELECT_IR_SCAN,
    CAPTURE_IR,
    SHIFT_IR,
    EXIT1_IR,
    PAUSE_IR,
    EXIT2_IR,
    UPDATE_IR
} jtag_state_t;

const jtag_state_t jtag_state_next[16][2] = {
    /* TEST_LOGIC_RESET */    { RUN_TEST_IDLE, TEST_LOGIC_RESET },
    /* RUN_TEST_IDLE */       { RUN_TEST_IDLE, SELECT_DR_SCAN },
    /* SELECT_DR_SCAN */      { CAPTURE_DR, SELECT_IR_SCAN },
    /* CAPTURE_DR */          { SHIFT_DR, EXIT1_DR },
    /* SHIFT_DR */            { SHIFT_DR, EXIT1_DR },
    /* EXIT1_DR */            { PAUSE_DR, UPDATE_DR },
    /* PAUSE_DR */            { PAUSE_DR, EXIT2_DR },
    /* EXIT2_DR */            { SHIFT_DR, UPDATE_DR },
    /* UPDATE_DR */           { RUN_TEST_IDLE, SELECT_DR_SCAN },
    /* SELECT_IR_SCAN */      { CAPTURE_IR, TEST_LOGIC_RESET },
    /* CAPTURE_IR */          { SHIFT_IR, EXIT1_IR },
    /* SHIFT_IR */            { SHIFT_IR, EXIT1_IR },
    /* EXIT1_IR */            { PAUSE_IR, UPDATE_IR },
    /* PAUSE_IR */            { PAUSE_IR, EXIT2_IR },
    /* EXIT2_IR */            { SHIFT_IR, UPDATE_IR },
    /* UPDATE_IR */           { RUN_TEST_IDLE, SELECT_DR_SCAN }
};

enum {
  IR_IDCODE=1,
  IR_DTMCONTROL=0x10,
  IR_DBUS=0x11,
  IR_MASK=0x1f,
};

#define IRBITS  5

static jtag_state_t state;
static jtag_state_t next_state;
static uint32_t ir;
static uint32_t dr;
static uint32_t dbus_last_data;
static bool busy = false;
struct vpi_cmd vpi;

static const uint32_t idcode = 0x00000ffd;

static uint32_t array_to_word(const void * bytes) {
    assert(bytes != NULL);

    const uint8_t * ptr = (const uint8_t *)bytes;

    return ptr[0] |
        ((uint32_t)ptr[1] << 8) |
        ((uint32_t)ptr[2] << 16) |
        ((uint32_t)ptr[3] << 24);
}

static void word_to_array(void * bytes, const uint32_t word) {
    assert(bytes != NULL);

    uint8_t * ptr = (uint8_t *)bytes;
    ptr[0] = word;
    ptr[1] = word >> 8;
    ptr[2] = word >> 16;
    ptr[3] = word >> 24;
}

static int do_scan(struct vpi_cmd * vpi, int * paddr, int * pdata, int * pop) {
    assert(vpi != NULL);
    assert(paddr != NULL);
    assert(pdata != NULL);
    assert(pop != NULL);

    switch (state) {
    case SHIFT_DR:
        if (ir == IR_IDCODE) {
            memcpy(vpi->buffer_in, vpi->buffer_out, vpi->length);
            word_to_array(vpi->buffer_in, idcode);
        }
        else if (ir == IR_DTMCONTROL) {
            uint32_t dtmcs;
            dtmcs = array_to_word(vpi->buffer_out);

            if (dtmcs & (3 << 16))
                DEBUG_PRINTF(__FILE__ ": reset (nyi)\n");

            // abits=6, version=1
            dtmcs = 0x0061;

            word_to_array(vpi->buffer_in, dtmcs);
        }
        else if (ir == IR_DBUS) {
            uint32_t op = vpi->buffer_out[0] & 3;
            uint32_t data = array_to_word(vpi->buffer_out);
            data = data >> 2 | ((uint32_t)vpi->buffer_out[4] << 30);
            uint32_t addr = (vpi->buffer_out[4] >> 2);

	    *pop = op;
	    *pdata = data;
	    *paddr = addr;

            if (op == 0) {
                // openocd seems to expect last read data on NOP
                *pdata = dbus_last_data;
                data = dbus_last_data;
            }
            else if (op == 1 || op == 2) {
		DEBUG_PRINTF(__FILE__ ": dmi request addr=0x%04x, data=0x%08x, op=%d)\n", addr, data, op);
		busy = true;
		return 1;
            }
            else {
                DEBUG_PRINTF(__FILE__ ": reserved dbus op (%d)\n", op);
            }

            word_to_array(vpi->buffer_in, data << 2);
            vpi->buffer_in[4] = (data >> 30) & 3;
        }
        else
            DEBUG_PRINTF(__FILE__ ": unknown register (%d)\n", ir);
        break;
    case SHIFT_IR:
        if (vpi->nb_bits == IRBITS) {
            vpi->buffer_in[0] = ir & IR_MASK;
            ir = vpi->buffer_out[0] & IR_MASK;
        }
        else if (vpi->nb_bits == (IRBITS + 2)) {
            // openocd IR capture validation
            vpi->buffer_in[0] = (ir & IR_MASK) | ((vpi->buffer_out[0] & 0x3) << IRBITS);
            ir = (vpi->buffer_out[0] >> 2) & IR_MASK;
        }
        else {
            DEBUG_PRINTF(__FILE__ ": IR scan NYI\n");
        }
        break;
    default:
        DEBUG_PRINTF(__FILE__ ": unknown scan state (%d)\n", state);
    }

    return 0;
}

static void jtag_vpi_response(int fd) {
    DEBUG_PRINTF("%s\n", __PRETTY_FUNCTION__);

    DEBUG_PRINTF(__FILE__ ": new state=%d\n", state);

    if (vpi.cmd == CMD_SCAN_CHAIN || vpi.cmd == CMD_SCAN_CHAIN_FLIP_TMS) {

#ifdef DEBUG
	{
	    DEBUG_PRINTF("    buffer_in =");

	    int i;
	    for (i = 0; i < vpi.length; i++) {
		DEBUG_PRINTF(" %02x", vpi.buffer_in[i]);
	    }

	    DEBUG_PRINTF("\n");
	}
#endif

	int c = write(fd, &vpi, sizeof(struct vpi_cmd));

	if (c >= 0 && c != sizeof(struct vpi_cmd)) {
	    DEBUG_PRINTF(__FILE__ ": short write\n");
	}
	else if (c < 0) {
	    perror("read() failed");
	    abort();
	}
    }
}

static int jtag_vpi_request(int fd, int * addr, int * data, int * op) {
    assert(fd >= 0);
    assert(addr != NULL);
    assert(data != NULL);
    assert(op != NULL);

    if (busy)
	return 0;

    int ret;

    //    DEBUG_PRINTF("%s\n", __PRETTY_FUNCTION__);

    struct pollfd fds[1];
    fds[0].fd = fd;
    fds[0].events = POLLIN;

    while (true) {
	ret = poll(fds, 1, 0);
	if (ret < 0) {
	    perror("poll() failed");
	    abort();
	}
	if (ret == 0) {
	    break;
	}

        int c = recv(fd, &vpi, sizeof(struct vpi_cmd), MSG_WAITALL);

        if (((c < 0) && (errno == EAGAIN)) || (c == 0)) {
	    ret = 0;
            break;
        }
        else if (c < 0) {
            perror("recv() failed");
            abort();
        }
	else if (c != sizeof(struct vpi_cmd)) {
	    // probably eof or an error
            abort();
	}

	DEBUG_PRINTF("%s\n", __PRETTY_FUNCTION__);

#ifdef DEBUG
        {
            DEBUG_PRINTF("vpi_cmd: cmd=%d, length=%d, nb_bits=%d, buffer_out =",
                    vpi.cmd, vpi.length, vpi.nb_bits);

            int i;
            for (i = 0; i < vpi.length; i++) {
                DEBUG_PRINTF(" %02x", vpi.buffer_out[i]);
            }

            DEBUG_PRINTF("\n");
        }
#endif

        DEBUG_PRINTF(__FILE__ ": state=%d, ir=%d\n", state, ir);

        switch ((uint32_t)vpi.cmd) {
        case CMD_RESET:
            DEBUG_PRINTF(__FILE__ ": CMD_RESET\n");
            state = TEST_LOGIC_RESET;
            ir = IR_IDCODE;
            break;
        case CMD_TMS_SEQ:
            DEBUG_PRINTF(__FILE__ ": CMD_TMS_SEQ\n");
            {
                int i;
                for (i = 0; i < vpi.nb_bits; i++) {
                    uint32_t mask = 1 << (i % 8);
                    uint32_t tms = vpi.buffer_out[i / 8] & mask;
                    state = jtag_state_next[state][(tms == 0) ? 0 : 1];
                }
            }
            break;
        case CMD_SCAN_CHAIN:
            DEBUG_PRINTF(__FILE__ ": CMD_SCAN_CHAIN\n");
            next_state = jtag_state_next[state][0];
            ret = do_scan(&vpi, addr, data, op);
	    if (ret > 0)
		return ret;
            state = next_state;
            break;
        case CMD_SCAN_CHAIN_FLIP_TMS:
            DEBUG_PRINTF(__FILE__ ": CMD_SCAN_CHAIN_FLIP_TMS\n");
            next_state = jtag_state_next[state][1];
            ret = do_scan(&vpi, addr, data, op);
	    if (ret > 0)
		return ret;
            state = next_state;
            break;
        }

	jtag_vpi_response(fd);
    }

    return ret;
}

int vpidmi_request(int fd, int * addr, int * data, int * op)
{
    assert(fd >= 0);
    assert(addr != NULL);
    assert(data != NULL);
    assert(op != NULL);

    return jtag_vpi_request(fd, addr, data, op);
}

int vpidmi_response(int fd, int data, int response)
{
    assert(fd >= 0);

    if (!busy) {
	DEBUG_PRINTF(__FILE__ ": unexpected dmi response\n");
	return -1;
    }

    busy = false;

    DEBUG_PRINTF(__FILE__ ": dmi response data=0x%08x, response=%d)\n", data, response);

    dbus_last_data = data;

    word_to_array(vpi.buffer_in, data << 2);
    vpi.buffer_in[4] = (data >> 30) & 3;

    state = next_state;

    jtag_vpi_response(fd);

    return 0;
}

#ifdef __cplusplus
}
#endif
