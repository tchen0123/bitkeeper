struct	{
	string	wm;		    // Windowing system: aqua, win32 or x11
	string	tool;		    // Name of the tool for configuration
	string	cmd_quit;	    // Command to quit the tool
	string	cmd_next;	    // Command to move to the next thing
	string	cmd_prev;	    // Command to move to the previous thing
	widget	w_top;		    // Toplevel window of the tool
	widget	w_main;		    // Main widget for scrolling and focus
	widget	w_search;	    // Text box that is the main search widget
	widget	w_searchBar;	    // Standard search bar for all tools
	int	search_case;	    // Search case-sensitive
	float	search_idx[2];	    // Current search index
	int	search_highlight;   // Highlight all search matches?
	widget	w_scrollbars{widget}[]; // Hash of scrollbars and their widgets
} _bk;

_bk.cmd_quit = "exit";

int	_bk_search_case = 0;
int	_bk_search_highlight = 0;

string
gc(string opt)
{
	return(::set("::gc(${opt})"));
}

string
bgExecInfo(string opt)
{
	return(::set("::bgExec(${opt})"));
}

void
bk_init()
{
	if (_bk.tool eq "") {
		bk_dieError("_bk.tool must be set before bk_init()", 1);
	}

	if ((string)_bk.w_top eq "") {
		bk_dieError("_bk.w_top must be set before bk_init()", 1);
	}

	_bk.wm = Tk_windowingsystem();
	bk_initPlatform();
	getConfig(_bk.tool);
	loadState(_bk.tool);
}

void
bk_initGui()
{
	restoreGeometry(_bk.tool, _bk.w_top);
	wm("protocol", _bk.w_top, "WM_DELETE_WINDOW", _bk.cmd_quit);
	wm("deiconify", _bk.w_top);

	bk_initSearch();
	bk_initBindings();
}

void
bk_initBindings()
{
	string	cmdkey = "Control";
	string	w, widgets[];

	// Add a special BK bindtag to every widget
	// in the application so that we can apply
	// bindings before everything else if we want.
	widgets = getAllWidgets(_bk.w_top);
	foreach (w in widgets) {
		string	tags[] = bindtags(w);
		bindtags(w, "BK ${tags}");
	}

	if (_bk.wm eq "aqua") cmdkey = "Command";
	bind("all", "<${cmdkey}-p>", _bk.cmd_prev);
	bind("all", "<${cmdkey}-n>", _bk.cmd_next);
	bind("all", "<${cmdkey}-q>", _bk.cmd_quit);

	bind("all", "<Control-b>",  "${_bk.w_main} yview scroll -1 pages");
	bind("all", "<Control-e>",  "${_bk.w_main} yview scroll  1 units");
	bind("all", "<Control-f>",  "${_bk.w_main} yview scroll  1 pages");
	bind("all", "<Control-y>",  "${_bk.w_main} yview scroll -1 units");
	bind("all", "<Shift-Up>",   "${_bk.w_main} yview scroll -1 units");
	bind("all", "<Shift-Down>", "${_bk.w_main} yview scroll  1 units");

	// Mouse wheel bindings
	if (_bk.wm eq "x11") {
		bind("BK", "<4>", "scrollMouseWheel %W %X %Y -3; break");
		bind("BK", "<5>", "scrollMouseWheel %W %X %Y  3; break");
	} else {
		bind("BK", "<MouseWheel>",
		    "scrollMouseWheel %W %X %Y %D; break");
	}

	if (_bk.wm eq "aqua") {
		// On OS X, we want to create a special proc that
		// is called when the user selects Quit from the
		// application menu.
		eval("proc ::tk::mac::Quit {} {${_bk.cmd_quit}}");
	}
}

void
bk_exit(...args)
{
	int	exitCode = 0;

	saveState(_bk.tool);
	if (llength(args) == 1) {
		exitCode = (int)args[0];
	} else if (llength(args) == 2) {
		exitCode = (int)args[1];
		if (exitCode == 0) {
			bk_die((string)args[0], exitCode);
		} else {
			bk_dieError((string)args[0], exitCode);
		}
	}
	exit(exitCode);
}

void
bk_message(string title, string message)
{
	if (Tk_windowingsystem() eq "win32") {
		tk_messageBox(title: title, message: message);
	} else {
		puts("stdout", message);
	}
}

void
bk_error(string title, string message)
{
	if (Tk_windowingsystem() eq "win32") {
		tk_messageBox(title: title, message: message);
	} else {
		puts("stderr", message);
	}
}

void
bk_die(string message, int exitCode)
{
	bk_message("BitKeeper", message);
	exit(exitCode);
}

void
bk_dieError(string message, int exitCode)
{
	bk_error("BitKeeper Error", message);
	exit(exitCode);
}

widget[]
getAllWidgets(widget top)
{
	widget	w, widgets[];
	widget	list[];

	widgets = winfo("children", top);
	foreach (w in widgets) {
		push(&list, w);
		widgets = getAllWidgets(w);
		foreach (w in widgets) {
			push(&list, w);
		}
	}
	return (list);
}

void
attachScrollbar(widget sb, ...args)
{
	int	i;
	poly	w;
	widget	widg, widgets[];
	string	orient = Scrollbar_cget(sb, orient:);

	foreach (w in args) {
		widgets[i++] = (widget)w;
	}
	if (orient eq "horizontal") {
		Scrollbar_configure(sb, command: "${widgets[0]} xview");
		foreach (widg in widgets) {
			_bk.w_scrollbars{widg} = widgets;
			Widget_configure(widg,
			    xscrollcommand: "setScrollbar ${sb} ${widg}");
		}
	} else {
		Scrollbar_configure(sb, command: "${widgets[0]} yview");
		foreach (widg in widgets) {
			_bk.w_scrollbars{widg} = widgets;
			Widget_configure(widg,
			    yscrollcommand: "setScrollbar ${sb} ${widg}");
		}
	}
}

void
setScrollbar(widget sb, widget w, float first, float last)
{
	widget	widg;
	float	x, y;
	float	xview[], yview[];

	Scrollbar_set(sb, first, last);
	unless (defined(_bk.w_scrollbars{w})) return;
	xview = Widget_xview(w);
	yview = Widget_yview(w);
	x = xview[0];
	y = yview[0];
	foreach (widg in _bk.w_scrollbars{w}) {
		if (widg == w) continue;
		Widget_xview(widg, "moveto", x);
		Widget_yview(widg, "moveto", y);
	}
}

void
scrollMouseWheel(widget w, int x, int y, int delta)
{
	int	d = delta;
	widget	widg = Winfo_containing(x, y);

	if (widg == "") widg = w;
	if (_bk.wm eq "aqua") {
		d = -delta;
	} else if (_bk.wm eq "x11") {
		d = (delta / 120) * -3;
	}
	// If we fail to scroll the widget the mouse is
	// over for some reason, just scroll the widget
	// with focus.
	if (catch("${widg} yview scroll ${d} units")) {
		catch("${w} yview scroll ${d} units");
	}
}