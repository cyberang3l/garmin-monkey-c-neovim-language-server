# garmin-monkey-c-neovim-language-server

This repo contains my LazyVim lspconfig for neovim. The main contribution
of this config is the addition of the Garmin MonkeyC LSP configuration to
allow neovim users to use the new language server that was provided by
Garmin with [SDK 8.1.0](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/connect-iq-sdk-8-1-0-now-available).

This is still work-in-progress (and may remain like this, as the plugin
already satisfies my needs), but it might be useful for others in its
current form, or as a foundation to build on it and add more features.

## What I have tested and works
* Go to definition
* Hover shows help messages and function signatures
* Auto-completion
* Warnings and compile errors

## Limitations
Many! What you find here is not very configurable, but as long as
you change the hardcoded device in the settings.testDevices (that is
currently set to "enduro3") to a device that your monkey C project
supports. The lsp configuration should work.

One more limitation is that you first have to compile your project
manually once, and after it's compiled, you can open nvim and use
the language server. The LSP will not keep recompiling the code (I think)
as the official Garmin VSCode plugin does, but somehow, it seems like
when writing code, the autocompletion and go-to-definition functionality
keeps working, and warnings and errors are showing up as they occur (
so it might be recompiling in the background and I haven't noticed from
the logs in ``~/.local/state/nvim/lsp.log``). Just in case recompilation
works, you may also want to point the plugin to the correct
developerKeyPath.
