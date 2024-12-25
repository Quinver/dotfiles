# Dotfiles

Welcome nerds, this is my arch(btw), hyprland  dotfiles repo! feel free to copy what you want.

---

## 🚀 Features

- Configurations for:
  - **Neovim**: Lightweight and customizable text editor
  - **Hyprland**: Dynamic Wayland compositor
  - **Waybar**: Status bar for Wayland
  - **Rofi**: Application launcher
  - **Kitty**: Fast, feature-rich terminal emulator
  - **Starship**: Minimal and blazing-fast prompt
  - **GTK and QT**: UI theming configurations
  - **Bash**: Custom `.bashrc` for shell tweaks

---

## 📂 Repository Structure

```plaintext
.
├── bashrc/           # Bash configurations
│   └── .bashrc
├── gtk-4.0/          # GTK theming
│   └── .config
├── hypr/             # Hyprland compositor configurations
│   └── .config
├── kitty/            # Kitty terminal configurations
│   └── .config
├── neovim/           # Neovim configurations
│   └── .config
├── qt5ct/            # QT theming
│   └── .config
├── rofi/             # Rofi launcher configurations
│   ├── .config
│   └── .local
├── starship/         # Starship prompt configurations
│   └── .config
└── waybar/           # Waybar configurations
    └── .config
```

---

## ⚙️ Installation

Follow these steps to get my dotfiles set up on your machine.

### 1. Clone the Repository

First, clone the dotfiles repository to your home directory:

```bash
git clone https://github.com/quinver/dotfiles.git ~/dotfiles
```
### 2. Manually Symlink the Files
I use [stow](https://www.gnu.org/software/stow/), download it with your favorite package manager.

Create symbolic links for each configuration file. For example:

cd into the folder:
```bash
cd ./dotfiles
```
```bash
stow bashrc
stow neovim
stow kitty
stow rofi
stow waybar
# Repeat for other configurations as needed
```

or all at once (I have not tried this):
```bash
stow * 
```

### 3. Install Dependencies

Make sure to install the necessary packages to make these configurations work. Here’s an example for Arch Linux using `yay`:

```bash
yay -S neovim kitty rofi hyprland waybar starship gtk3 gtk4 qt5ct qt6ct
```

Customize this list according to your needs and distribution.

---

## 🛠️ Customization

These configurations are optimized for my setup, but feel free to explore and tweak them to fit your needs. The primary configuration files include:

- `.bashrc` for Bash shell customization
- `neovim/` for Neovim configurations
- `kitty/` for Kitty terminal settings
- `starship/` for the Starship prompt configuration
- `hypr/` and `waybar/` for Wayland-related setups
- `gtk-4.0/` and `qt5ct/` for UI theming

---

## 🌟 Notes

- Designed for systems using **Wayland** and **Arch Linux** or a similar distro.
- Assumes you have basic knowledge of symlinking files and working with the terminal.
- Package manager `yay` is required for some dependencies, but you can use your preferred package manager.

---

## 📜 License

This repository is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute these configurations.

---

Happy configuring! ✨
