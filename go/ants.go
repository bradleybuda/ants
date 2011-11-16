package main

import (
	"os"
	"bufio"
	"strconv"
	"strings"
	"fmt"
	"log"
)

//Bot interface defines what we need from a bot
type Bot interface {
	DoTurn(s *State) os.Error
}

var stdin = bufio.NewReader(os.Stdin)

//Start takes the initial parameters from stdin
func (s *State) Start() os.Error {

	for {
		line, err := stdin.ReadString('\n')
		if err != nil {
			return err
		}
		line = line[:len(line)-1] //remove the delimiter

		if line == "" {
			continue
		}

		if line == "ready" {
			break
		}

		words := strings.SplitN(line, " ", 2)
		if len(words) != 2 {
			panic(`"` + line + `"`)
			return os.NewError("invalid command format: " + line)
		}

		param, _ := strconv.Atoi(words[1])

		switch words[0] {
		case "loadtime":
			s.LoadTime = param
		case "turntime":
			s.TurnTime = param
		case "rows":
			s.Rows = param
		case "cols":
			s.Cols = param
		case "turns":
			s.Turns = param
		case "viewradius2":
			s.ViewRadius2 = param
		case "attackradius2":
			s.AttackRadius2 = param
		case "spawnradius2":
			s.SpawnRadius2 = param
		case "player_seed":
			param64, _ := strconv.Atoi64(words[1])
			s.PlayerSeed = param64
		case "turn":
			s.Turn = param

		default:
			log.Panicf("unknown command: %s", line)
		}
	}

	// TODO this init stuff should probably go elsewhere
	s.CreateSquares()
	s.Stats = new(Stats)

	return nil
}

//Loop handles the majority of communication between your bot and the server.
//b's DoWork function gets called each turn after the map has been setup
//BetweenTurnWork gets called after a turn but before the map is reset. It is
//meant to do debugging work.
func (s *State) Loop(b Bot, BetweenTurnWork func()) os.Error {

	//indicate we're ready
	os.Stdout.Write([]byte("go\n"))

	for {
		line, err := stdin.ReadString('\n')
		if err != nil {
			if err == os.EOF {
				return err
			}
			log.Panicf("ReadString returns an error: %s", err)
			return err
		}
		line = line[:len(line)-1] //remove the delimiter

		if line == "" {
			continue
		}

		if line == "go" {
			// just about to start the turn, clean up unsensed items
			AllItems.DestroyUnsensed(s)

			b.DoTurn(s)

			//end turn
			s.endTurn()

			BetweenTurnWork()

//			s.Map.Reset()
			continue
		}

		if line == "end" {
			break
		}

		words := strings.SplitN(line, " ", 5)
		if len(words) < 2 {
			log.Panicf("Invalid command format: \"%s\"", line)
		}

		switch words[0] {
		case "turn":
			turn, _ := strconv.Atoi(words[1])
			if turn != s.Turn+1 {
				log.Panicf("Turn number out of sync, expected %v got %v", s.Turn+1, turn)
			}
			s.Turn = turn

			s.ResetSquares()
			s.AdvanceAllAnts()
		case "f":
			if len(words) < 3 {
				log.Panicf("Invalid command format (not enough parameters for food): \"%s\"", line)
			}

			Row, _ := strconv.Atoi(words[1])
			Col, _ := strconv.Atoi(words[2])
			square := s.SquareAtRowCol(Row, Col)
			if square.HasFood() {
				square.item.Sense(s)
			} else {
				s.NewFood(square)
			}
		case "w":
			if len(words) < 3 {
				log.Panicf("Invalid command format (not enough parameters for water): \"%s\"", line)
			}

			Row, _ := strconv.Atoi(words[1])
			Col, _ := strconv.Atoi(words[2])
			square := s.SquareAtRowCol(Row, Col)
			square.Destroy()
		case "a":
			if len(words) < 4 {
				log.Panicf("Invalid command format (not enough parameters for ant): \"%s\"", line)
			}
			Row, _ := strconv.Atoi(words[1])
			Col, _ := strconv.Atoi(words[2])
			Owner, _ := strconv.Atoi(words[3])
			square := s.SquareAtRowCol(Row, Col)

			if Owner == 0 {
				ant := square.ant

				if ant == nil {
					if square.HasHill() && square.item.IsMine() {
						ant = s.NewAnt(square)
					} else {
						log.Panicf("No record of my ant at %v", square)
					}
				}

				// TODO mark at as dead if necessary
			}
		case "h":
			if len(words) < 4 {
				log.Panicf("Invalid command format (not enough parameters for hill): \"%s\"", line)
			}
			Row, _ := strconv.Atoi(words[1])
			Col, _ := strconv.Atoi(words[2])
			Owner, _ := strconv.Atoi(words[3])
			square := s.SquareAtRowCol(Row, Col)

			if square.HasHill() {
				square.item.Sense(s)
			} else {
				s.NewHill(Owner, square)
			}
		case "d":
			if len(words) < 4 {
				log.Panicf("Invalid command format (not enough parameters for dead ant): \"%s\"", line)
			}
//			Row, _ := strconv.Atoi(words[1])
//			Col, _ := strconv.Atoi(words[2])
//			Ant, _ := strconv.Atoi(words[3])
//			loc := s.Map.FromRowCol(Row, Col)
//			s.Map.AddDeadAnt(loc, Item(Ant))

		}
	}

	return nil
}

//Call IssueOrderLoc to issue an order for an ant at loc
func (s *State) IssueOrderLoc(loc Location, d Direction) {
	fmt.Fprintf(os.Stdout, "o %d %d %s\n", loc.Row(s), loc.Col(s), d)
}

//endTurn is called by Loop, you don't need to call it.
func (s *State) endTurn() {
	os.Stdout.Write([]byte("go\n"))
}
