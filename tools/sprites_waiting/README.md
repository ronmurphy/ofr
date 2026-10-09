# Sprites waiting for their looks

Drawings for looks the game does not have yet. They live here, not in
`assets/sprites/`, because the suite fails on a sprite named after a look
the game never draws (`_test_every_sprite_is_a_look_the_game_draws`).

When the look exists, move the file:

| file | look | goes to | icon for the picture look |
|---|---|---|---|
| `spider.txt` | the spider, `&"spider"` (wild, so in the wild gold) | `assets/sprites/creatures/` | md-spider, `0xF11EA` |
| `web.txt` | the web tile, `&"web"` | `assets/sprites/features/` | md-spider_web, `0xF0BCA` |

The file name must be the appearance id exactly. If the look is named
differently, rename the file and its `name:` line to match.

The web is a terrain feature. Under the pixel look a feature with a
drawing is drawn from it, and every other feature keeps its picture.
