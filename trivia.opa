// TODO: don't go into negative territory
// display user points in real time

import stdlib.themes.bootstrap

INIT_POINTS = 200;
ASK_POINTS = 50;
WIN_POINTS = 100;
LOSE_POINTS = 25;

type question = { string author, string text, string answer, bool open }
type user = { int points }
type event = { question new, int num } or { int wrong, string fool } or { int solved, string by }

database intmap(question) /questions;
database /questions[_]/open = { false }
database stringmap(user) /users;
database int /count = 0;

Network.network(event) room = Network.cloud("room");

server function check(num, answer) {
	question = /questions[num];
	question.open && answer == question.answer;
}

function user_points(u) {
	match (?/users[u]) {
		case { none }: INIT_POINTS;
		case { some: { ~points } }: points;
	}
}

server function post_question(q) {
	if (user_points(q.author) >= ASK_POINTS) {
		user = /users[q.author];
		/users[q.author] <- { user with points: user.points - ASK_POINTS };
		num = /count + 1;
		/count <- num;
		/questions[num] <- q;
		Network.broadcast({ question: q, ~num }, room);
		"Posted"
	} else {
		"Not enough points"
	}
}

server function post_answer(num, user, answer, _) {
	if (check(num, answer)) {
		/questions[num] <- { /questions[num] with open: false };
		u = /users[user];
		/users[user] <- { points: u.points + WIN_POINTS };
		Network.broadcast({ solved: num, by: user })
	} else {
		u = /users[user];
		/users[user] <- { points: u.points - LOSE_POINTS };
		Network.broadcast({ wrong: num, fool: user })
	}
}

client function user_update(user, x) {
    match (x) {
    	case { ~new, ~num }:	
			line =
				<div class="container" id="c{num}"> 
				<div class="row line">
					<div class="span1 columns userpic" />
    				<div class="span1 columns user">{new.text}?</>
					<div class="span13 columns message"><input id="q{num}" onnewline={post_answer(num, user, Dom.get_value("q{num}"), _)}/></>
				</div>
				</div>;
			#conversation =+ line;
		case { ~solved, ~by }:
			message = 
				if (by == user) { "Congratulations. You win that one." }
				else { "You should have been faster. This question was solved by {by}." };
			q = /questions[solved];
			#{"c{solved}"} = 
				<div class="row line">Q: {q.text}</>
				<div class="row line">A: {q.answer}</>
				<div class="row line"><div class="message">{message}</></>;
		case { ~wrong, ~fool }:
			message = 
				if (fool == user) { "Oh no, you're making a fool out of yourself." }
				else { "{fool} ridiculously fails answering that one." };
			#{"c{wrong}"} =+ <div>{message}</div>;
	}			
}

function broadcast(x) {
	Network.broadcast(x, room);
	Dom.clear_value(#entry);
}

function main() {
	author = Random.string(8);
	send = function(_) {
		question = Dom.get_value(#question);
		answer = Dom.get_value(#answer);
		output = post_question({~author, ~question, ~answer, open: true});
		#feedback = output;
	};	
	<div class="topbar"><div class="fill"><div class="container">
		<div id=#logo />
	</div></div></div>
	<div id=#conversation class="container" onready={
		function(_) { Network.add_callback(user_update(author, _), room); } 
	}></div>
	<div id=#footer><div class="container">
		<input id=#question onnewline={Dom.give_focus(#question)}/>
		<input id=#answer onnewline={send}/>
		<div class="btn primary" onclick={send}>Post</div>
		<div id="feedback"/>
	</div></div>
}

Server.start(
	Server.http,
	[ { resources: @static_resource_directory("resources") },
	  { register: ["resources/css.css"] },
	  { title: "SocialTrivia", page: main } ]
)
