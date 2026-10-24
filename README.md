cliquote
========

Displays a random quote in your command line.

The original source, clearquot.es, is gone, so quotes now come from
[DummyJSON](https://dummyjson.com/docs/quotes), with [ZenQuotes](https://zenquotes.io)
as a fallback. If neither answers (no network, rate limit, outage), a built-in
quote is shown instead, so the command always prints something.

## Requirements

Ruby 2.7 or newer. Only the standard library is used, so there are no gems to install.

## Usage

    ruby cliquote.rb

or make it executable and put it on your `PATH`:

    chmod +x cliquote.rb
    cp cliquote.rb ~/bin/cliquote
    cliquote

To get a quote every time you open a terminal, add `cliquote` to the end of your
`~/.bashrc` or `~/.zshrc`.

### Options

    -s, --source NAME    Use only this source (dummyjson, zenquotes)
    -o, --offline        Use the built-in quotes, no network
    -w, --width N        Output width (default: terminal width)
    -v, --verbose        Report sources that failed
    -p, --pause          Wait for Enter before exiting
    -h, --help           Show this help

On Windows, double-clicking `cliquote.rb` also works: the window stays open
until you press Enter.

## Screenshot

![Screenshot](screenshot.png)

Screenshot by <a href="https://twitter.com/Pedroh96" target="_blank">@Pedroh96</a>
