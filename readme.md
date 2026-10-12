# Always-On Bookmarks Bar

Keeps the bookmarks toolbar permanently visible in Zen Browser.

With Zen's default layout (single toolbar + hidden window controls), the top
strip that holds the bookmarks toolbar collapses and only appears while you
hover over the top edge of the window. This mod keeps that strip expanded, so
your bookmarks are always one click away. The page sits below the bar instead
of underneath it, so nothing is covered and nothing jumps when you hover.

Works in both normal and compact mode.

## Installation

**With [Sine](https://github.com/CosmoCreeper/Sine):** search for
"Always-On Bookmarks Bar" in the Sine marketplace, or add it directly by
entering `TheTrueFerret/zen-always-on-bookmarks-bar`.

**Manually:** copy the contents of [`chrome.css`](chrome.css) into
`chrome/userChrome.css` in your Zen profile folder (find it via
`about:support` > Profile Folder), set
`toolkit.legacyUserProfileCustomizations.stylesheets` to `true` in
`about:config`, and restart Zen.

## Usage

1. Install the mod.
2. Make sure the bookmarks toolbar itself is enabled: press
   `Ctrl+Shift+B` (`Cmd+Shift+B` on macOS), or right-click the top bar and
   choose **Bookmarks Toolbar > Always Show**.

If the bookmarks toolbar is set to **Never Show** or **Only Show on New Tab**,
the mod respects that and does nothing on pages where the toolbar is hidden.

## Notes

- Only affects the default single-toolbar layout. In the multiple-toolbars
  layout Zen already keeps the bookmarks toolbar visible (unless you enabled
  "hide toolbar" in compact mode, which this mod leaves alone).
- The bar is hidden in fullscreen video as usual.

## License

MIT
