module Visualize

import util::Webserver;

loc visLoc = |http://localhost:10001|;

@doc {
    Sends the given value to the visualization website
}
void visualize(value val) {
    // Special exception for base string values, since we have to insert the quotes
    if (str _:_ := val) val = "\"<val>\"";

    Response testServer(get("/data")) = response("<val>", header = ("Access-Control-Allow-Origin": "*"));

    try {
        stopVisualize();
        serve(visLoc, testServer);
        return;
    }
    catch value exception:
        throw exception;
}

@doc {
    Stops the server used for visualizing the last sent data
}
bool stopVisualize() {
    try {
        shutdown(visLoc);
        return true;
    } catch value exception:
         throw exception;
    finally {
        return false;
    }
}

// Constructors
@doc {
    Rascal-vis control constructors. These allow you to modify properties programmatically, which can also be modified in the UI manually. 
}
public data RascalVisControls 
    // Selects the settings profile to be shown
    = VProfile(
        // The value to be visualized
        value val, 
        // The name of the profile to create/load
        str name="", 
        // The name of the profile to copy from, if the profile doesn't exist yet
        str init="", 
        // The settings to apply in this profile
        RascalVisSettings settings=VSettings()
    )
    // Shows a given node in the visualizer
    | VShow(
        // The value to be shown in some way
        value val, 
        // Whether to select the value to be highlighted
        bool highlight=false, 
        // Whether to reveal the value in the data tree
        bool reveal=true, 
        // Whether to show all occurences of this value in the tree
        bool revealAll=false
    )
    // Selects the tab that this value should be shown in
    | VTab(
        // The value to be shown in a dedicated tab
        value val,
        // The name of the tab to show the value in
        str name="",
        // The tab to copy settings from, if a tab with this name doesn't exist already
        str init=""
    );

@doc {
    Rascal-vis settings.
}
public data RascalVisSettings = VSettings(
    // Whether to delete panels that are no longer used
    bool layoutDeleteUnusedPanels=true,
    // The highlighting intensity when hovering over a value
    real textHoverHighlightIntensity=0.3,
    // The highlighting intensity when fully selecting a value
    real textHighlightIntensity=1,
    // Whether to show the sizes of sets in front of the set
    bool textShowSetSize=true,
    // Whether to show the sizes of lists in front of the lists
    bool textShowListSize=true,
    // Whether to show the sizes of tuples in front of the tuples
    bool textShowTupleSize=false,
    // Whether to show the sizes of maps in front of the map
    bool textShowMapSize=false,
    // The sharpness of the graph to render
    real graphSharpness=1.5,
    // The number of results to load on the initial search
    int searchInitialLoadCount=50,
    // The number of items to load when pressing load more
    int searchExpandLoadCount=50,
    // Whether to show layout symbols in the grammar
    bool grammarShowLayout=false,
    // The minimum lhs width in the grammar, for better alignment
    int grammarAlignWidth=150,
    // When to show the grammar expansion handles
    str grammarShowHandle="hover"
);

@doc {
    Rascal-vis graph data type, to visualize graphs
}
public data RascalVisGraph = VGraph(
    // The nodes of the graph
    set[RascalVisGraphNode] nodes,
    // The edges of the graph
    set[RascalVisGraphEdge] edges,
    // Whether the graph should be fully undirected
    bool undirected=false,
    // The source data that this graph was created from
    value source=false,
    // Any additional meta data for the graph 
    value meta=false  
);

public data RascalVisGraphNode = VNode(
    // The identifier of this node
    value id,
    // The name to display for the node
    str name="",
    // The color to assign to the node
    str color="",
    // The highlight color to use when the node is selected
    str highlightColor="",
    // The source data that this node was created from
    value source=false,
    // Any additional meta data for the node
    value meta=false  
);

public data RascalVisGraphEdge = VEdge(
    // The id of the node that the edge should go from
    value from,
    // The id of the node that the edge should go to
    value to, 
    // The name to display for the edge
    str name="",
    // Whether the node should be undirected
    bool undirected=false,
    // The color to assign to the edge
    str color="",
    // The highlight color to use when the edge is selected
    str highlightColor="",
    // The source data that this edge was created from
    value source=false,
    // Any additional meta data for the edge
    value meta=false  
);

@doc {
    Rascal-vis grammar augmentation, text annotations will be vshown
}
data Symbol = annotate(Symbol sym, set[value] annotations);