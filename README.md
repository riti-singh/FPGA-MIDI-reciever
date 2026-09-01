# FPGA MIDI Receiver

A small VHDL design that receives classic 5-pin DIN MIDI serial data and exposes decoded three-byte messages to downstream FPGA logic. The repository contains the receiver RTL, a restricted message parser, a self-checking simulation testbench, and a Basys 3-oriented LED demonstration top level.

This is the original implementation by Riti Singh, cleaned up and documented for reproducibility. The repository does not contain the larger synthesizer/DDS project referenced by early project notes.

## Engineering problem

MIDI transports musical events over an asynchronous serial link, while an FPGA processes synchronous logic. This design bridges those domains by:

1. synchronizing the external receive signal to the FPGA clock;
2. detecting the beginning of a serial frame;
3. sampling each frame near the center of its bits;
4. reconstructing an eight-bit byte; and
5. grouping three received bytes into status, key, and velocity outputs.

The outputs can feed a later sound-generation or control block. No sound synthesis, MIDI transmitter, or SPI interface is included here.

## MIDI framing used by this design

The MIDI 1.0 electrical transport sends asynchronous serial data at **31,250 bit/s**, with one start bit (`0`), eight data bits sent least-significant bit first, and one stop bit (`1`). There is no parity bit. One frame therefore occupies 320 microseconds.

Channel Voice status bytes use the upper nibble for the message type and the lower nibble for the channel. For example, `0x90` is Note On on channel 1 (the wire-level channel value is zero), followed by key and velocity data bytes. `0x80` similarly identifies Note Off.

Not every MIDI message has three bytes. The parser in this repository intentionally implements only a fixed three-byte grouping; see [Limitations](#limitations).

## Architecture

```text
serial_in
    |
    v
sync_start -> midi_baud -> bit_counter10
                       \-> shift_reg10 -> byte_valid
                                            |
                                            v
                                      midi_parser
                                            |
                       status, key, velocity, event pulses
```

`midi_receiver` is the reusable integration top level. The receive pin is passed through a two-flop synchronizer. A falling edge starts a baud timer, which first waits half a bit period and then samples the start, eight data, and stop bits at one-bit intervals. `midi_parser` latches every three valid bytes and emits one-clock `message_ready`, `note_on`, or `note_off` pulses.

### Source files

| File | Purpose |
| --- | --- |
| `midi_receiver.vhd` | Reusable receiver and parser top level |
| `midi_uart_rx.vhd` | MIDI-rate UART receive state machine |
| `midi_sync_start.vhd` | Input synchronizer and falling-edge detector |
| `midi_baud.vhd` | Half-bit and full-bit sample timing |
| `bit_counter10.vhd` | Counts the ten sampled frame bits |
| `shift_reg10.vhd` | Stores start, data, and stop samples |
| `midi_parser.vhd` | Groups bytes and identifies `0x8n`/`0x9n` status nibbles |
| `midi_receiver_tb.vhd` | Self-checking Note On/Note Off simulation |
| `midi_hw_test.vhd` | Basys 3-style LED demonstration wrapper |
| `pulse_stretcher.vhd` | Makes one-clock event pulses visible on LEDs |
| `midi_byte_rx.vhd` | Earlier, currently unused byte-receiver implementation retained for authorship/history |

## Interfaces and current behavior

The `midi_receiver` generic `CLK_HZ` defaults to 100 MHz. Its active-high `rst` is synchronous within each module.

After every three received bytes:

- `event_channel` holds the first byte (normally a status byte);
- `key` and `velocity` hold the second and third bytes;
- `message_ready` pulses for one FPGA clock;
- `note_on` pulses when the saved status upper nibble is `0x9`; and
- `note_off` pulses when the saved status upper nibble is `0x8`.

The hardware demonstration displays key or velocity on LEDs 7:0, the status upper nibble on LEDs 11:8, stretched event indicators on LEDs 14:12, and a heartbeat on LED 15.

## Verification

`midi_receiver_tb.vhd` sends two complete UART/MIDI messages:

- Note On: `90 3C 40`
- Note Off: `80 3C 00`

The testbench checks the reconstructed byte order, parsed fields, and classification pulses, then stops cleanly under VHDL-2008. This is a focused smoke test, not exhaustive protocol verification.

With [GHDL](https://github.com/ghdl/ghdl) installed, run from the repository root:

```sh
ghdl -a --std=08 midi_sync_start.vhd midi_baud.vhd bit_counter10.vhd shift_reg10.vhd midi_uart_rx.vhd midi_parser.vhd midi_receiver.vhd midi_receiver_tb.vhd
ghdl -e --std=08 midi_receiver_tb
ghdl -r --std=08 midi_receiver_tb --assert-level=error
```

For synthesis, add the RTL files to a VHDL-2008-capable FPGA project and select either `midi_receiver` or `midi_hw_test` as the top level. Set `CLK_HZ` to the actual board clock. The repository does **not** include a board constraints file, so clock, reset, MIDI input, switch, and LED pins must be constrained for the target board. A suitable MIDI input circuit or adapter must provide the FPGA-compatible logic-level `serial_in`; do not connect a 5-pin MIDI current-loop signal directly to an FPGA pin.

## Limitations

- The parser blindly groups bytes in sets of three. It does not validate that the first byte is a status byte or that following bytes are data bytes.
- Running status, one- and two-data-byte message types, System Common messages, System Exclusive, and interleaved System Real-Time bytes are not handled.
- MIDI's convention that Note On with velocity zero is equivalent to Note Off is not implemented; it still raises `note_on`.
- Start and stop samples are captured but not validated, and no framing-error output is provided.
- Baud timing uses integer clock division. A clock frequency that is not an exact multiple of 31,250 introduces truncation error; no fractional divider or oversampling is implemented.
- The included testbench covers two nominal messages only. It does not test jitter, malformed frames, reset during reception, back-to-back frames without extra idle time, or clock/baud mismatch.
- `midi_hw_test` names Basys 3 signals, but no constraints file or captured hardware evidence is included. Hardware operation is therefore not claimed by this repository.

## Repository status

The design is suitable as a compact educational RTL example and as a starting point for a more complete MIDI front end. Before production use, the parser should become status-aware, framing checks and error recovery should be added, and verification should cover the unsupported and boundary cases listed above.


