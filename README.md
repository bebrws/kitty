I had added a keyboard event handler for

command control a

that will keep the kitty terminal window always on top

If ran as root it will register the event globally
Otherwise the kitty window will need to be in focus for it to recieve the keyboard event
