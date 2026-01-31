# vim-ticker

**Real-time stock ticker views directly inside Vim**

A lightweight Vim plugin that lets you display live/updating ticker prices for stocks right in your editor — without ever leaving Vim.

Inspired by classic ticker tapes and status monitors, but built for modern terminal workflows.
![Live scrolling ticker tape showing stock prices in Vim](images/img1.png?raw=true "TickerTape view with TSLA, NVDA, AAPL (termguicolors)")
![Live scrolling ticker tape showing stock prices in Vim](images/img2.png?raw=true "TickerTape view with TSLA, NVDA, AAPL (notermguicolors)")

## Features

- **Live ticker display** — scrollable marquee-style tape with prices & changes
- **Simple chart view** — basic price history visualization (ASCII or simple bars)
- **Multiple views** — switch between tape, chart, or combined display
- **MVC-inspired architecture** — core controller (`:Ticker` / `:NoTicker`) manages data fetching/updates; separate commands handle views
- **Non-blocking** — uses timers/jobs (where available) so it doesn't freeze your editing
- Works in both Vim 8+ and Neovim

## Commands

| Command                  | Description                              | Notes                              |
|--------------------------|------------------------------------------|------------------------------------|
| `:Ticker [args...]`      | Start monitoring one or more tickers     | Only entry point                   |
| `:NoTicker`              | Stop monitoring & remove all tickers     | Only exit point                    |
| `:TickerTape`            | Show scrolling ticker tape view          |                                    |
| `:NoTickerTape`          | Hide the ticker tape                     |                                    |
| `:TickerChart`           | Show price chart view                    |                                    |
| `:NoTickerChart`         | Hide the chart                           |                                    |
| `:NextTickerChart`       | Cycle to next chart/symbol               |                                    |
| `:PrevTickerChart`       | Cycle to previous chart/symbol           |                                    |

**Example usage:**

```vim
" Watch AAPL, TSLA
:Ticker AAPL TSLA

" Show the scrolling tape
:TickerTape

" Show a chart (if implemented)
:TickerChart

" Switch charts
:NextTickerChart

" Stop everything
:NoTicker

!**NOTE**!
Must launch vim from a shell with an active Python environment that has *yfinance* installed. 
