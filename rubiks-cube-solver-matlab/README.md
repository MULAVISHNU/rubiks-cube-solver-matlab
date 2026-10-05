# Rubik's Cube Solver (MATLAB)

Take six photos of a scrambled 3x3 Rubik's cube, and this MATLAB script reads
the sticker colors, lets you confirm them, and prints a step-by-step solution
using Kociemba's two-phase algorithm.

## How it works

1. **Photos**: you select one photo per face and crop it to the 3x3 grid.
2. **Color detection**: the middle of each sticker is sampled and classified
   by its nearest face-center color in Lab space, which tolerates lighting
   differences.
3. **Confirmation**: an unfolded net of the cube is shown so you can check
   the colors and correct any face by typing its 9 letters.
4. **Solving**: the cube string goes to the Python
   [`kociemba`](https://pypi.org/project/kociemba/) package, and the moves
   are printed with plain-English descriptions.

## Requirements

- MATLAB R2020b or newer, with the **Image Processing Toolbox**
- Python 3 configured for MATLAB (check with `pyenv`)
- The `kociemba` Python package

```
python -m pip install -r requirements.txt
```

## Usage

```matlab
rubiks_solver
```

### How to hold the cube for each photo

Centers: U = White, R = Red, F = Green, D = Yellow, L = Orange, B = Blue.
Start with white on top and green facing you.

| Face | Photo instructions |
|------|--------------------|
| W (white)  | From above, green edge at the **bottom** of the photo |
| R (red)    | Red facing you, white edge at the top |
| G (green)  | Green facing you, white edge at the top |
| Y (yellow) | From below, green edge at the **top** of the photo |
| O (orange) | Orange facing you, white edge at the top |
| B (blue)   | Blue facing you, white edge at the top |

Keep the camera square-on to the face, with even, diffuse lighting.

## Troubleshooting

**`pip install kociemba` fails with "Failed to build installable wheels"**
(common on Windows). The package contains a C extension and needs either a
prebuilt wheel or a compiler.

1. Try a prebuilt wheel: `python -m pip install --only-binary :all: kociemba`
2. If none exists for your Python version, use Python 3.10 or 3.11 and point
   MATLAB at it: `pyenv('Version','C:\Path\To\Python311\python.exe')`
3. Or install *Visual Studio Build Tools* with the "Desktop development with
   C++" workload and rerun the install.

After installing, restart MATLAB (or run `terminate(pyenv)`) so it sees the
new package.

**"Solver rejected the cube"**: a sticker was misread or a photo had the wrong
orientation. Rerun and fix the faces in the confirmation step.

**Colors misdetected**: use brighter, even light, avoid glare, and crop tightly
around the 3x3 grid.

## Project layout

```
rubiks_solver.m    main script (function name must match the filename)
requirements.txt   Python dependency
README.md
LICENSE
.gitignore
```

## License

MIT, see [LICENSE](LICENSE).
