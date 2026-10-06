#ifndef COMM_API_H
#define COMM_API_H

#include <stdint.h>
#include "dt_link.h"
#include "dt_protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Initialize the comm subsystem (dt_link runtime + K1 button policy).
   Must be called exactly once, after peripheral init and BEFORE arming any
   UART RX DMA (the RX ISR calls Comm_Feed, which dereferences the link).
   ops: send/now_us function pointers; must outlive the comm subsystem.
   read_button: returns non-zero when the pin is high (released), zero when
   low (pressed). */
void Comm_Init(const dt_link_ops_t *ops, int (*read_button)(void));

/* Feed received bytes into channel ch (0=serial, 1=BT).
   Called from UART RX interrupt context: no locking, no allocation. */
void Comm_Feed(uint8_t ch, const uint8_t *data, uint16_t len);

/* Poll the K1 button and drive the BT pairing policy:
   press -> enable BT (SEARCHING); release -> after 3s confirm, drop BT.
   Call once per main-loop tick. */
void Comm_PollButton(void);

/* Run the channel state machine (heartbeat timeouts, BT acquire/reconnect). */
void Comm_Update(void);

/* Send a STATE_REPORT frame (angles already scaled by 10). */
void Comm_SendState(uint8_t mode, uint16_t target, uint16_t actual, uint8_t status);

/* Extract the next business frame from the active channel. Heartbeat REQs
   are answered automatically inside the link runtime and never surface here.
   Returns 1 if a frame was extracted into *frame, 0 if none available. */
int Comm_ExtractFrame(dt_frame_t *frame);

/* Request a Bluetooth reconnect. */
void Comm_RequestReconnectBT(void);

/* Current link arbitration state (for diagnostics/tests). */
dt_link_state_t Comm_LinkState(void);

#ifdef __cplusplus
}
#endif

#endif /* COMM_API_H */
