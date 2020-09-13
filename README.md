I had added a keyboard event handler for

command control a

that will keep the kitty terminal window always on top

If ran as root it will register the event globally
Otherwise the kitty window will need to be in focus for it to recieve the keyboard event


NOTE - now the app will actually aquire the rights to create a mach port and listen for global keyboard events if this fails a local keyboard event listener will be used like before
