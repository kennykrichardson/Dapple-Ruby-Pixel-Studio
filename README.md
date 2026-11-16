# 🎨 Dapple

### A Pixel Studio by Kenny Richardson

**A desktop pixel-art editor meets a reproducible procedural-art laboratory.**

Dapple gives you a hands-on pixel editor, a collection of expressive color universes, and a procedural generation system driven by editable parameters and reproducible seeds. Sketch pixel by pixel, generate a landscape from a seed, explore nearby mutations, then export the result as a crisp PNG.

![Dapple interface theme](https://img.shields.io/badge/UI-CRIMSON%20%7C%20GOLD%20%7C%20CREAM-9B263B?style=flat-square)
![Ruby](https://img.shields.io/badge/Ruby-4.0%2B-CC342D?style=flat-square&logo=ruby&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-E7C46A?style=flat-square)

---

## ✨ Highlights

- 🖌️ **Pixel editor:** brush, eraser, fill, eyedropper, line, rectangle, ellipse, and mirror-paint tools.
- 🧬 **Procedural generation:** noise, radial symmetry, terrain, cellular automata, and Bayer dithering.
- 🎛️ **Live Pattern DNA:** tune nine generator parameters with draggable controls and live previews.
- 🌱 **Reproducible seeds:** revisit a composition exactly, copy seeds from mutations, or paste your own.
- 🧪 **Evolution Chamber:** explore a 3 × 3 mutation grid and apply a variation with one undoable action.
- 🌈 **Eight color universes:** Moss, Sunset, Ocean, Candy, Arcade, Neon, Earth, and Mono.
- 🗂️ **Project workflow:** import PNGs, save and load `.dapple` projects, autosave, and export transparent PNGs.
- ↩️ **Undo and redo:** up to 100 history states, including one-step procedural edits.
- 🧰 **Headless core:** use the generators and PNG exporter without launching the desktop UI.

## 🖥️ The Studio

Dapple's workspace is arranged into three focused areas:

| Area | What's inside |
| --- | --- |
| **Toolbox** | Drawing tools, brush footprints, symmetry, color universes, and palette utilities |
| **Canvas** | Pixel-art workspace, grid, zoom, canvas size, undo, and redo |
| **Project Vault** | PNG/project actions, Pattern DNA controls, seed editing, and the Evolution Chamber |

The interface uses a dark neutral foundation with **crimson, light gold, and creamy white** accents. The eight color universes keep their own palettes rather than inheriting the interface colors. Evolution previews use square cards so every generated variation gets equal space.

On Windows, Dapple opens in a decorated, maximized window while retaining the native title bar and taskbar.

## 🧑‍🎨 Pixel Editing

- Artboard sizes: **32 × 32, 48 × 48, 64 × 64, 96 × 96, and 128 × 128**.
- Tools: brush, eraser, flood-fill bucket, eyedropper, line, rectangle, ellipse, and mirror paint.
- Brush footprints: **1, 2, 3, 4, 6, and 8 pixels**.
- Live painting symmetry: off, four-fold, and eight-fold.
- Pixel grid, checkerboard transparency, brush preview, zoom, and keyboard panning.
- Incremental rendering: ordinary strokes update only affected 16 × 16 render tiles.
- 100-step undo/redo history. No-op edits do not consume history.

## 🌈 Color Universes

Choose from eight built-in six-color palettes:

| Palette | Character |
| --- | --- |
| 🌿 **Moss** | Earthy greens and soft natural highlights |
| 🌅 **Sunset** | Dusky purples, warm reds, and golden light |
| 🌊 **Ocean** | Deep blues, teal, and sea-glass tones |
| 🍬 **Candy** | Pastels, pinks, and soft violet |
| 🕹️ **Arcade** | Electric blues, bright green, and yellow |
| 💜 **Neon** | High-contrast violet, magenta, and orange |
| 🏜️ **Earth** | Clay, sandstone, and warm neutrals |
| ⚪ **Mono** | A complete grayscale range |

The Palette Lab also supports custom hex colors, gradient ramps, imported GIMP `.gpl` and JSON palettes, multi-page swatches, and explicit remapping of existing artwork. Changing palettes does not silently recolor the current document; use **Remap Art** when you want to translate existing pixels.

## 🧬 Pattern DNA & Generation

Every generated composition is determined by an algorithm, a set of DNA parameters, and an integer seed. Reuse the same inputs to reproduce the same output.

### Included algorithms

- 🌫️ **Noise:** smooth, multi-octave value noise.
- ✳️ **Symmetry:** radial rotational symmetry.
- 🌄 **Terrain:** midpoint-displacement terrain with a sun and stars.
- 🧫 **Cellular:** cellular automata.
- ▦ **Bayer:** 4 × 4 Bayer dithering.

### Live DNA controls

- Noise density and octave count
- Symmetry seed count
- Terrain roughness and horizon
- Noise persistence
- Cellular density and steps
- Bayer density

Drag a slider to preview the new composition. Releasing the control records the complete adjustment as one undoable change.

### 🌱 Seeds & Evolution

The Evolution Chamber generates nine nearby DNA mutations. Select a square preview to apply its composition to the main canvas. Select its seed label to copy that seed, then paste it into the editable seed field with **Ctrl+V** or **Shift+Insert**. The field also supports **Ctrl+A**, **Ctrl+C**, and **Ctrl+X**; press **Enter** to apply or **Escape** to cancel.

## 📦 Import, Projects & Export

- **Import PNG:** scale an image to the active artboard using nearest-neighbor sampling, preserve transparency, and quantize visible pixels to the selected palette.
- **Save / Load:** store dimensions, pixels, palette, generator, DNA parameters, and seed in a `.dapple` project file.
- **Autosave:** snapshots are written to `~/.dapple/autosave.dapple` after edits and generation.
- **Export PNG:** export transparent PNGs at **4×, 8×, 16×, 24×, or 32×** scale. The default is 16×, producing a 2,048 × 2,048 image from a 128 × 128 artboard.
- **Export location:** generated images are written to the project's `exports/` directory with unique filenames.

File operations use native operating-system dialogs.

## ⚙️ Requirements

- **Ruby 4.0 or newer** for the Ruby2D desktop application.
- **Ruby 3.2 or newer** for the headless core and CLI.
- Bundler for dependency management.
- A desktop environment supported by [Ruby2D](https://www.ruby2d.com/learn/get-started/).

On Windows, use [RubyInstaller with DevKit](https://rubyinstaller.org/). Ruby2D requires native SDL dependencies; consult the [Ruby2D setup guide](https://www.ruby2d.com/learn/get-started/) for platform-specific setup.

## 🚀 Install & Run

```bash
gem install bundler
bundle install
bundle exec ruby bin/dapple
```

The desktop editor opens in a decorated, monitor-aware window. On Windows, the window is maximized after startup without hiding the taskbar.

## 🧑‍💻 Headless CLI

The `generate` command uses the core generator and exporter without loading Ruby2D:

```bash
bundle exec ruby bin/dapple generate --algorithm terrain --seed 42 out.png
```

A more configurable example:

```bash
bundle exec ruby bin/dapple generate \
  --algorithm noise \
  --seed 42 \
  --size 128 \
  --palette Arcade \
  --density 0.84 \
  --octaves 5 \
  --scale 4 \
  out.png
```

Supported algorithm names: `noise`, `symmetry`, `terrain`, `cellular`, and `bayer`.

## 💎 Ruby API

The same generator can be used from a Ruby script:

```ruby
require 'dapple'

generator = Dapple::Generator.new do |g|
  g.algorithm = :terrain
  g.width = 128
  g.height = 128
  g.palette = Dapple::Palettes.fetch('Moss')
  g.seed = 42
  g.params = Dapple::PatternDNA.new(terrain_roughness: 0.7).to_h
end

pixels = generator.generate
```

`pixels` is a height-by-width matrix containing hex colors and `nil` for transparent pixels. Use it with `Dapple::Document#replace!` or the PNG exporter.

## 🧪 Tests

Run the Minitest suite:

```bash
rake test
```

The suite covers document bounds and resizing, deterministic generators, DNA mutation, undo/redo, rasterization, project round-trips, and PNG import/export when `chunky_png` is installed. GitHub Actions runs the test suite on pushes and pull requests.

## 🗃️ Project Structure

```text
Dapple/
├── bin/dapple
├── lib/
│   ├── dapple.rb
│   └── dapple/
│       ├── clipboard.rb
│       ├── document.rb
│       ├── editor.rb
│       ├── exporter.rb
│       ├── generators.rb
│       ├── history.rb
│       ├── importer.rb
│       ├── palettes.rb
│       ├── pattern_dna.rb
│       ├── project.rb
│       ├── raster.rb
│       └── ui/button.rb
├── spec/
├── exports/.gitkeep
├── .github/workflows/ci.yml
├── .gitignore
├── CHANGELOG.md
├── Gemfile
├── LICENSE
├── README.md
├── Rakefile
└── dapple.gemspec
```

## 📄 License

Dapple is released under the [MIT License](LICENSE).

---

# 🛠️ Engineered by Kenny Richardson Kodipally
