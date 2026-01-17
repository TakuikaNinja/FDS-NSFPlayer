# FDS NSF Player

NSF player program for the Famicom Disk System.

The source NSF data is statically included alongside the player program without any modifications, so this is only compatible with simple/small NSF files which do not use bankswitching. Supported audio types are 2A03 only and 2A03 + FDS.

The NSF Title, Artist, and Copyright fields are automatically displayed by the program, along with a basic interface to change songs and start/stop playback.

## Disclaimer

Commercial game rips are not intended nor expected to work on this player. Please do not use this player as a means of distributing/selling NSF music without permission from the owner or copyright holder. 

## Usage

1. Clone this repo and install the [CC65 suite](https://cc65.github.io/).
2. Run the included `parse_nsf.py` script with the path to the desired NSF file as an argument to generate the required `nsfdata.asm` file.
3. Optionally, edit the line length values in `constants.asm` to tweak the display for the Title, Artist, and Copyright fields.
4. Run `make` to assemble the `nsfplay.fds` program file.
5. Load/run the program on FDS hardware/emulators.

Example:

```
./parse_nsf.py nsf/example.nsf
make
```

### NSF file requirements

These are checked by the parser script or the CA65 source:
- NSF/NSF2 format only (NSFe is unsupported)
- No bankswitching
- NTSC speed, ~60Hz only (PAL speed songs are played faster, custom speeds are unsupported)
- No expansion audio other than FDS (i.e. 2A03 only or 2A03 + FDS)
- No accesses to 0x0100-0x0103 and/or 0x6000-0x7FFF (reserved by player program)
- NSF data & load/init/play addresses must fit within 0x8000-0xDFFF
  - FDS disk game vectors at 0xDFF6-0xDFFF are overwritten by the player program
- No NSF2 features (warning only, as optional metadata chunks are probably harmless)

YMMV for anything else not specified here. No guarantees or warranties are provided.

## Controls

Controller 1 only:
- Left/Right - change song number.
- Start - start/stop song playback.

IMPORTANT: The player will write to the FDS wave volume (0x4080) and 2A03 status (0x4015) registers when stopping playback, thus it expects the NSF init routine to properly initialise these before using them for playback. Depending on the NSF file, a soft reset may need to be performed if audio oddities occur after stopping or restarting playback.

## Example Screenshot

Song: [All A Dragon Can Eat](https://youtu.be/d_2zBO894_k) - [NSF download](https://file.garden/ZWWUbm2eyH6XVYLi/NSF%2BEmu%20Playback%20Files/NSF/Originals/AllADragonCanEat.nsf)

![Screenshot for example NSF](/img/example.png)

## Acknowledgements

This project was largely inspired by the following projects:
- ["played NSF with N-Line AT 1/2" by MUTRON / Yasuyuki Hirata](https://youtu.be/GWXZW5JjLVw) - NSF playback on FDS via custom RAM adapter serial protocol
- [NSF Player FDS by OffGao](http://offgao.net/program/nsfpfds.html) - NSF playback on FDS via disk loading

This project uses the following placeholder assets:
- `Jroatch-chr-sheet.chr` was converted from the following placeholder CHR sheet: https://www.nesdev.org/wiki/File:Jroatch-chr-sheet.chr.png
  - It contains tiles from Generitiles by Drag, Cavewoman by Sik, and Chase by shiru.

