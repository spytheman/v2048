import gg
import gx
import os
import rand
import sokol.sapp

struct Tile {
	id      int
	points  int
	picname string
}

struct Pos {
	x int = -1
	y int = -1
}

struct TextLabel {
	text string
	pos  Pos
	cfg  gx.TextCfg
}

struct ImageLabel {
	pos Pos
	dim Pos
}

const (
	window_title        = 'v2048'
	window_width        = 562
	window_height       = 562
	points_label        = TextLabel{
		text: 'Points: '
		pos: Pos{10, 5}
		cfg: gx.TextCfg{
			align: gx.align_left
			size: 24
			color: gx.rgb(0, 0, 0)
		}
	}
	moves_label         = TextLabel{
		text: 'Moves: '
		pos: Pos{window_width - 160, 5}
		cfg: gx.TextCfg{
			align: gx.align_left
			size: 24
			color: gx.rgb(0, 0, 0)
		}
	}
	game_over_label     = TextLabel{
		text: 'Game Over'
		pos: Pos{80, 220}
		cfg: gx.TextCfg{
			align: gx.align_left
			size: 100
			color: gx.rgb(0, 0, 255)
		}
	}
	victory_image_label = ImageLabel{
		pos: Pos{80, 220}
		dim: Pos{430, 130}
	}
	all_tiles           = [
		Tile{0, 0, '1.png'},
		Tile{1, 2, '2.png'},
		Tile{2, 4, '4.png'},
		Tile{3, 8, '8.png'},
		Tile{4, 16, '16.png'},
		Tile{5, 32, '32.png'},
		Tile{6, 64, '64.png'},
		Tile{7, 128, '128.png'},
		Tile{8, 256, '256.png'},
		Tile{9, 512, '512.png'},
		Tile{10, 1024, '1024.png'},
		Tile{11, 2048, '2048.png'},
		Tile{12, 4096, '4096.png'},
		Tile{13, 8196, '8196.png'},
	]
)

struct TileImage {
	tile  Tile
mut:
	image gg.Image
}

// TODO: remove the .str() method here. It is just to prevent C compilation errors
// about sg_image_str
fn (t &TileImage) str() string {
	return 'TileImage{ Tile{id: $t.tile.id, points: $t.tile.points, picname: $t.tile.picname } }'
}

//
struct Board {
mut:
	field  [4][4]int
	points int
	shifts int
}

fn (b Board) transpose() Board {
	mut res := b
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			res.field[y][x] = b.field[x][y]
		}
	}
	return res
}

fn (b Board) hmirror() Board {
	mut res := b
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			res.field[y][x] = b.field[y][4 - x - 1]
		}
	}
	return res
}

struct TileLine {
	ypos   int
mut:
	field  [5]int
	points int
	shifts int
}

fn no_newlines(s string) string {
	return s.replace('\n', ' ')
}

//
fn (t TileLine) to_left() TileLine {
	right_border_idx := 5
	mut res := t
	mut zeros := 0
	mut nonzeros := 0
	// gather meta info about the line:
	for x := 0; x < 4; x++ {
		if res.field[x] == 0 {
			zeros++
		} else {
			nonzeros++
		}
	}
	if nonzeros == 0 {
		// when all the tiles are empty, there is nothing left to do
		return res
	}
	if zeros > 0 {
		// we have some 0s, do shifts to compact them:
		mut remaining_zeros := zeros
		for x := 0; x < right_border_idx - 1; x++ {
			for res.field[x] == 0 && remaining_zeros > 0 {
				res.shifts++
				for k := x; k < right_border_idx; k++ {
					res.field[k] = res.field[k + 1]
				}
				remaining_zeros--
			}
		}
	}
	// At this point, the non 0 tiles are all on the left, with no empty spaces
	// between them. we can safely merge them, when they have the same value:
	for x := 0; x < right_border_idx - 1; x++ {
		if res.field[x] == 0 {
			break
		}
		if res.field[x] == res.field[x + 1] {
			for k := x; k < right_border_idx; k++ {
				res.field[k] = res.field[k + 1]
			}
			res.shifts++
			res.field[x]++
			res.points += all_tiles[res.field[x]].points
		}
	}
	// eprintln('TileLine.to_left shifts: $res.shifts | zeros: $zeros | nonzeros: $nonzeros\n${no_newlines(t.str())}\n${no_newlines(res.str())}\n-----------------------------------')
	return res
}

fn (b Board) to_left() Board {
	mut res := b
	for y := 0; y < 4; y++ {
		mut hline := TileLine{ypos:y}
		for x := 0; x < 4; x++ {
			hline.field[x] = b.field[y][x]
		}
		reshline := hline.to_left()
		res.shifts += reshline.shifts
		res.points += reshline.points
		for x := 0; x < 4; x++ {
			res.field[y][x] = reshline.field[x]
		}
	}
	return res
}

//
enum GameState {
	play
	over
	victory
}

struct App {
mut:
	gg            &gg.Context
	tiles         []TileImage
	victory_image gg.Image
	//
	board         Board
	undo          []Board
	atickers      [4][4]int
	state         GameState = .play
	moves         int
}

fn (mut app App) new_tile(t Tile) TileImage {
	mut timage := TileImage{
		tile: t
	}
	timage.image = app.gg.create_image(os.resource_abs_path(os.join_path('assets', t.picname)))
	return timage
}

fn (mut app App) load_tiles() {
	for t in all_tiles {
		app.tiles << app.new_tile(t)
	}
	// eprintln('tiles: $app.tiles')
}

fn (mut app App) update_tickers() {
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			mut old := app.atickers[y][x]
			if old > 0 {
				old--
				app.atickers[y][x] = old
			}
		}
	}
}

fn (app &App) draw() {
	app.draw_tiles()
	app.gg.draw_text(points_label.pos.x, points_label.pos.y, '$points_label.text ${app.board.points:08}',
		points_label.cfg)
	app.gg.draw_text(moves_label.pos.x, moves_label.pos.y, '$moves_label.text ${app.moves:5d}',
		moves_label.cfg)
	if app.state == .over {
		app.gg.draw_text(game_over_label.pos.x, game_over_label.pos.y, game_over_label.text,
			game_over_label.cfg)
	}
	if app.state == .victory {
		app.gg.draw_image(victory_image_label.pos.x, victory_image_label.pos.y, victory_image_label.dim.x,
			victory_image_label.dim.y, app.victory_image)
	}
}

fn (app &App) draw_tiles() {
	border := 10
	xstart := 10
	ystart := 30
	tsize := 128
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			tidx := app.board.field[y][x]
			tile := app.tiles[tidx]
			tw := tsize - 10 * app.atickers[y][x]
			th := tsize - 10 * app.atickers[y][x]
			app.gg.draw_image(xstart + x * (tsize + border) + (tsize - tw) / 2, ystart +
				y * (tsize + border) + (tsize - th) /
				2, tw, th, tile.image)
		}
	}
}

fn (mut app App) new_game() {
	app.board = Board{}
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			app.board.field[y][x] = 0
			app.atickers[y][x] = 0
		}
	}
	app.state = .play
	app.undo = []
	app.moves = 0
	app.new_random_tile()
	app.new_random_tile()
}

fn (mut app App) check_for_victory() {
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			fidx := app.board.field[y][x]
			if fidx == 11 {
				app.victory()
				return
			}
		}
	}
}

fn (mut app App) check_for_game_over() {
	mut zeros := 0
	mut remaining_merges := 0
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			fidx := app.board.field[y][x]
			if fidx == 0 {
				zeros++
				continue
			}
			if x > 0 && fidx == app.board.field[y][x - 1] {
				remaining_merges++
			}
			if x < 4 - 1 && fidx == app.board.field[y][x + 1] {
				remaining_merges++
			}
			if y > 0 && fidx == app.board.field[y - 1][x] {
				remaining_merges++
			}
			if y < 4 - 1 && fidx == app.board.field[y + 1][x] {
				remaining_merges++
			}
		}
	}
	if remaining_merges == 0 && zeros == 0 {
		app.game_over()
	}
}

fn (mut app App) new_random_tile() {
	mut etiles := [16]Pos{}
	mut empty_tiles_max := 0
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			fidx := app.board.field[y][x]
			if fidx == 0 {
				etiles[empty_tiles_max] = Pos{x, y}
				empty_tiles_max++
			}
		}
	}
	if empty_tiles_max > 0 {
		new_random_tile_index := rand.intn(empty_tiles_max) or {0}
		empty_pos := etiles[new_random_tile_index]
		random_value := 1 + rand.intn(2) or {0}
		app.board.field[empty_pos.y][empty_pos.x] = random_value
		app.atickers[empty_pos.y][empty_pos.x] = 30
		// eprintln('>>>>> new_random_tile, app.board.points: $app.board.points | random_value: $random_value at ${no_newlines(empty_pos.str())}')
	}
	app.check_for_victory()
	app.check_for_game_over()
}

fn (mut app App) victory() {
	app.state = .victory
}

fn (mut app App) game_over() {
	app.state = .over
}

type BoardMoveFN = fn(b Board) Board
fn (mut app App) move(move_fn BoardMoveFN) {
	old := app.board
	new := move_fn(old)
	if old.shifts != new.shifts {
		app.moves++
		app.board = new
		app.undo << old
		app.new_random_tile()
	}
}

fn (mut app App) on_key_down(key sapp.KeyCode) {
	// these keys are independent from the game state:
	match key {
		.escape {
			exit(0)
		}
		.space {
			app.new_random_tile()
		}
		.n {
			app.new_game()
		}
		.backspace {
			if app.undo.len > 0 {
				app.state = .play
				app.board = app.undo.pop()
				app.moves--
				return
			}
		}
		else {}
	}
	if app.state == .play {
		match key {
			.up, .w { app.move(fn (b Board) Board {
					return b.transpose().to_left().transpose()
				}) }
			.left, .a { app.move(fn (b Board) Board {
					return b.to_left()
				}) }
			.down, .s { app.move(fn (b Board) Board {
					return b.transpose().hmirror().to_left().hmirror().transpose()
				}) }
			.right, .d { app.move(fn (b Board) Board {
					return b.hmirror().to_left().hmirror()
				}) }
			else {}
		}
	}
	// eprintln('app.board.points: $app.board.points')
}

//
fn on_event(e &sapp.Event, mut app App) {
	if e.@type == .key_down {
		app.on_key_down(e.key_code)
	}
}

fn frame(mut app App) {
	app.update_tickers()
	app.gg.begin()
	app.draw()
	app.gg.end()
}

fn main() {
	mut app := &App{
		gg: 0
		state: .play
	}
	app.new_game()
	app.gg = gg.new_context(
		bg_color: gx.white
		width: window_width
		height: window_height
		use_ortho: true
		create_window: true
		window_title: window_title
		frame_fn: frame
		event_fn: on_event
		user_data: app
		font_path: os.resource_abs_path(os.join_path('assets', 'RobotoMono-Regular.ttf'))
	)
	app.load_tiles()
	app.victory_image = app.gg.create_image(os.resource_abs_path(os.join_path('assets',
		'victory.png')))
	app.gg.run()
}
