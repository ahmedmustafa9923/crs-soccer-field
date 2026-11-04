# CRS Soccer Field

A five-a-side soccer game for kids, for iPhone and iPad in landscape. Built with SwiftUI and SpriteKit. It needs no internet, accounts, ads or in-app purchases.

## How to play

- **Run:** drag your left thumb anywhere on the left half of the screen.
- **KICK:** shoots at goal. Far from goal, it kicks the ball up the field. Without the ball, it becomes **DASH**, a quick sprint to win the ball back.
- **PASS:** passes to the best open teammate, or the one you're pointing at. Without the ball, it becomes **SWITCH** to pick another player.
- The player you control has a glowing yellow ring and their name above them. Control switches to whoever is closest to the ball.

## What's in a match

- **Opening ceremony:** the teams walk out of the tunnel, line up, and fireworks go off over cheering fans. Tap to skip.
- **The match:** goals, saves, throw-ins, corners and goal kicks, with a referee who follows play and blows the whistle. The scoreboard shows the score, minute and half.
- **Half-time:** a marching band crosses the pitch and the stats show (score, shots, ball time). The teams then switch ends.
- **Full time and closing ceremony:** the teams line up, a trophy appears, confetti falls and the star player is named.
- **Figures and animation:** cartoon players in team kits with running, standing and arms-up celebration poses. Goalkeepers wear gloves. The referee runs with play and raises his arm when he whistles. The net bulges when the ball goes in, a shot can ring off the post, and a player bumped by the ball or a tackle stumbles.
- **Crowd:** tiered stands full of fans in team shirts, scarves and hats. Some hold signs with the players' names ("GO SAM!", "ZARA 8"). Printed player banners and the team name hang on the stand fronts, flags wave, and CRS advertising boards line the touchlines. Fans throw their arms up and wave their signs when their team scores.
- **Ball and pitch:** the ball really rolls. Its panels turn across a shaded sphere in the direction it moves, faster the harder it's hit. The pitch has mowing stripes, thousands of grass blades and worn patches in the goalmouths and centre circle.
- **Crowd symphony:** Mexican waves run around the ground, with signs held high, at the opening, half-time, the end and about every 26 seconds of play. Card displays turn a whole stand into a picture: fans hold up coloured cards that spell the team names at the opening, "GOAL!" when their team scores, and "WINNERS" at the end.
- **Real football:**
  - **Power meter:** hold KICK or PASS and a meter fills yellow, orange, then red (strongest). The player draws the leg back while it charges and swings it through on release. Strong shots fly and can sail over the bar; strong passes are lofted.
  - **SKILL button:** with the ball it does a roulette, step-over or rainbow flick. Without the ball it does a slide tackle, which wins the ball more often but risks a foul.
  - **Headers and bicycle kicks:** the ball has real height, with its shadow staying on the grass. High balls are headed. Near goal, tap KICK as the ball drops for a bicycle kick.
  - **Fouls and cards:** tackles from behind or sliding in can be fouls. The referee runs over, blows hard and holds up a yellow or red card. Two yellows make a red, and a red-carded player walks off.
  - **Stamina:** a bar over every player's head, green, yellow, then red. Sprinting and dashing drain it, and tired players slow down and sweat. Fresh legs come back for the second half.
  - **A fair contest:** when you lead or keep the ball, the other team speeds up, tackles harder and shoots more accurately, so they are always at least as good as you.
  - **Running and staff:** players lean into their runs with a bounce in each stride, kicking up dust when sprinting. Goalkeepers hold the ball in their hands. Teammates high-five the scorer.
  - **Touchline:** each team's manager and mentor stand by the dugouts and react to goals. A mini-map at the bottom shows your players as circles, theirs as triangles, and the ball.
- **Before kick-off:** a locker-room team talk (lockers with the players' names, team flags, bunting, the manager and mentor speaking), then the players on the benches, then the walk-out led by the referee carrying the ball, high fives along the line, fireworks and card displays. The referee spins the ball on one finger and places it on the centre spot.
- **Sound:** crowd murmur, crowd roar for goals and ceremonies, kicks, a thump when the ball or a tackle hits a body or legs, the referee's whistle (long for half-time and full time), the net's swish and the post's ping. All sounds are made in code and respect the silent switch.
- **Settings:** team names, 2, 3 or 5 minutes per half, and levels Rookie, Pro and Star. Your wins, draws and losses are saved on the device.

## Modes

| Mode | What it is | Rewards |
|---|---|---|
| **Play!** (quick match) | A full match with both ceremonies | Win 10 coins, draw 5, loss 2, plus 1 per goal |
| **Practice** | Shoot at a goalkeeper, with no clock. End it from the pause menu | 1 coin a goal, up to 10 |
| **Training** | Three drills, up to 3 stars each: Shooting (goals in 45 s), Dribbling (6 gates, fastest time), Passing (8 passes in 45 s) | 3 coins a star. 3 stars in every drill earns the Training Star trophy |
| **Tournament** | The CRS Cup: quarter-final, semi-final, final. Knockout, so a draw goes to penalties | Cup win: 50 coins and a trophy. Runners-up: 20 coins and a silver medal |
| **Season** | The CRS League: 6 teams, 5 matchdays, 3 points for a win and 1 for a draw, with a live table | Champions: 60 coins and a trophy. 2nd: 25 coins and silver. 3rd: 15 coins and bronze |
| **Prizes** | Trophy cabinet, 10 badges (first goal, hat-trick, clean sheet and more) and lifetime stats | |
| **Shop** | Team kits (green, purple, black, pink, gold) and balls (star, gold, rainbow) | Paid for with CRS coins |

CRS coins are tokens earned only by playing. There is no real money and nothing to buy with money, which keeps the game safe for kids. Progress is saved on the device.

The other teams (Rockets, Comets, Tigers, Sharks, Dragons, Eagles, Wolves, Lions) are made up. They play at the level the child picks, or harder in later rounds.

## Files

| File | What it does |
|---|---|
| `SoccerApp.swift` | App entry, menu, match screen with pause |
| `GameScene.swift` | Pitch, fans, players, ball, rules, controls, AI, scoreboard |
| `Ceremonies.swift` | Opening ceremony, half-time show, closing ceremony, effects |
| `Player.swift` | Player and referee figures, drawn in code, with animation |
| `Sound.swift` | All sound effects, made in code |
| `Crowd.swift` | Fans, signs, banners, flags and advertising boards |
| `Drills.swift` | Practice and the three training drills |
| `Moves.swift` | Power meter, skills, headers, bicycle kicks, fouls and cards, stamina, matched AI, staff, benches, mini-map |
| `Progress.swift` | Coins, trophies, badges, shop items, cup and league, saved on the device |
| `Modes.swift` | Training, Tournament, Season, Prizes, Shop and reward screens |
| `Basics.swift` | Vector maths, settings, colours, textures |

## Later

An Apple Watch companion, Game Center and a web version.
