# vim-ticker

**Real-time stock/crypto ticker views directly inside Vim**

A lightweight Vim plugin that lets you display live/updating ticker prices for stocks, indices, crypto, etc., right in your editor — without ever leaving Vim.

Inspired by classic ticker tapes and status monitors, but built for modern terminal workflows.

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
| `:Ticker [args...]`      | Start monitoring one or more tickers     | Main entry point                   |
| `:NoTicker`              | Stop monitoring & remove all tickers     | Main exit point                    |
| `:TickerTape`            | Show scrolling ticker tape view          | Marquee-style price display        |
| `:NoTickerTape`          | Hide the ticker tape                     |                                    |
| `:TickerChart`           | Show price chart view                    | Simple ASCII or line chart         |
| `:NoTickerChart`         | Hide the chart                           | (alias: `:HideChart`)              |
| `:NextTickerChart`       | Cycle to next chart/symbol               | If multiple symbols                |
| `:PrevTickerChart`       | Cycle to previous chart/symbol           | If multiple symbols                |

**Example usage:**

```vim
" Watch AAPL, TSLA and BTC-USD
:Ticker AAPL TSLA BTC-USD

" Show the scrolling tape
:TickerTape

" Show a chart (if implemented)
:TickerChart

" Switch charts
:NextTickerChart

" Stop everything
:NoTicker
