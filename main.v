import gg
import gx
import os
import rand
import sokol.sapp

const (
	window_title = 'v2048'
    window_width = 562
    window_height = 562
)

struct Tile {
	id int
	picname string
mut:	
	image gg.Image
}
fn (t &Tile) str() string { return 'Tile{ id: $t.id, picname: $t.picname }' }
//
struct Board {
mut:
	field [4][4]int
	points int
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
			res.field[y][x] = b.field[y][4-x-1]
		}
	}
	return res
}

struct TileLine {
	ypos int
mut:
	field [6]int
	points int
}
fn (t TileLine) to_left() TileLine {
	right_border_idx := 6-1
	mut res := t
	for x := 0; x<right_border_idx; x++ {
		if t.field[x] == 0 {
			for k := x; k < right_border_idx; k++ {
				res.field[k] = t.field[k+1]
			}
			continue
		}
		if t.field[x] == t.field[x+1] {
			res.points += t.field[x]
			res.field[x] = t.field[x]+1
			for k := x; k < right_border_idx; k++ {
				res.field[k] = t.field[k+1]
			}
		}
	}
	eprintln('TileLine.to_left:\n$t\n$res\n-----------------------------------')
	return res
}

fn (b Board) to_left() Board {
	mut res := b
	for y := 0; y < 4; y++ {
		mut hline := TileLine{y}
		for x := 0; x < 4; x++ {
			hline.field[1+x] = b.field[y][x]
		}
		reshline := hline.to_left()
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
	win
	over
}
struct App {
mut:
    gg &gg.Context
	tiles []Tile
	//
	board Board
	atickers [4][4]int
	state GameState = .play
}

fn (mut app App) new_tile(id int, picname string) Tile {
	mut tile := Tile{id, picname}
	tile.image = app.gg.create_image(os.resource_abs_path(os.join_path('assets', picname)))
	return tile
}

fn (mut app App) load_tiles() {
	app.tiles = [
		app.new_tile(0, '1.png')
		app.new_tile(1, '2.png')
		app.new_tile(2, '4.png')
		app.new_tile(3, '8.png')
		app.new_tile(4, '16.png')
		app.new_tile(5, '32.png')
		app.new_tile(6, '64.png')
		app.new_tile(7, '128.png')
		app.new_tile(8, '256.png')
		app.new_tile(9, '512.png')
		app.new_tile(10, '1024.png')
		app.new_tile(11, '2048.png')
		app.new_tile(12, '4096.png')
		app.new_tile(13, '8196.png')
		]
	eprintln('tiles: $app.tiles')
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
}

fn (app &App) draw_tiles() {
	border := 10
	xstart := 10
	ystart := 10
	tsize := 128
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			tidx := app.board.field[y][x]
			tile := app.tiles[tidx]
			tw := tsize - 10*app.atickers[y][x]
			th := tsize - 10*app.atickers[y][x]
			app.gg.draw_image(xstart + x*(tsize+border) + (tsize-tw)/2, ystart + y*(tsize+border) + (tsize-th)/2, tw, th, tile.image)
		}
	}
}

fn (mut app App) clear_field() {
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			app.board.field[y][x] = 0
			app.atickers[y][x] = 0
		}
	}
}

struct Pos {
	x int = -1
	y int = -1
}
fn (mut app App) new_random_tile() {
	mut etiles := [16]Pos
	mut etiles_max := 0
	for y := 0; y < 4; y++ {
		for x := 0; x < 4; x++ {
			fidx := app.board.field[y][x]
			if fidx == 0 {
				etiles[etiles_max] = Pos{x,y}
				etiles_max++
			}
		}
	}
	if etiles_max > 0 {
		new_random_tile_index := rand.intn(etiles_max)
		empty_pos := etiles[new_random_tile_index]
		random_value := 1 + rand.intn(2)
		app.board.field[ empty_pos.y ][ empty_pos.x ] = random_value
		app.atickers[ empty_pos.y ][ empty_pos.x ] = 30
	} else {
		app.game_over()
	}
}

fn (mut app App) game_over() {
	app.state = .over 
}

fn (mut app App) move(dx int, dy int) {
	eprintln('move: $dx $dy')
}

fn (mut app App) on_key_down(key sapp.KeyCode) {
	match key {
		.escape {
			exit(0)
		}
		.up, .w {
			app.move(-1,0)
			app.board = app.board.transpose().hmirror().to_left().hmirror().transpose()
		}
		.left, .a {
			app.move(0,-1)
			app.board = app.board.to_left()
		}
		.down, .s {
			app.move(1,0)
			app.board = app.board.transpose().to_left().transpose()
		}
		.right, .d {
			app.move(0,1)
			app.board = app.board.hmirror().to_left().hmirror()
		}
		else {}
	}
	eprintln('app.board.points: $app.board.points')
	app.new_random_tile()
}

//

fn on_event(e &sapp.Event, mut app App) {
	if e.typ == .key_down {
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
    mut app := &App{gg:0}
	app.clear_field()
	app.new_random_tile()
	app.new_random_tile()
    app.gg = gg.new_context(
        bg_color: gx.white
        width: window_width
        height: window_height
        use_ortho: true // This is needed for 2D drawing
        create_window: true
        window_title: window_title
        frame_fn: frame
		event_fn: on_event
        user_data: app
    )
	app.load_tiles()
    app.gg.run()
}
