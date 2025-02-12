"
I'm an adapter to render a TreeTablePresenter with Gtk3.

Since Gtk3 uses a GtkTreeStore to render the tree, and it needs to exists previously (but you can edit it with iterators), I use a trick to not pre-render all elements at once (a task that can be very time/space consuming depending on the tree to present): I use an event of the tree (test-row-expanded) to add a new level to the children of the item I'm expanding. 
Confused? Let's see an example: Let's suppose I have this tree: 

A
	B1
		C1
		C2
	B2
	

In first iteration, I will add just this levels to the store: 

A
	B1
	B2
	
Which will ensure ""A"" will show the expand arrow (since it has children). Now, when I expand ""A"", I need to dig into its children and add childs (to ensure B1 will show an expansion row).
After processing, we will the full tree.  
"
Class {
	#name : #GtkTreeTableAdapter,
	#superclass : #GtkAdapter,
	#traits : 'GtkTDisconnectSelectionEvents + GtkTHaveWrappingScrollBars + GtkTSortableColumns',
	#classTraits : 'GtkTDisconnectSelectionEvents classTrait + GtkTHaveWrappingScrollBars classTrait + GtkTSortableColumns classTrait',
	#instVars : [
		'levelsAdded',
		'objectCache',
		'defaultColumn'
	],
	#category : #'Spec-Gtk-Adapter-Table'
}

{ #category : #building }
GtkTreeTableAdapter >> addKeyBindingsTo: gtkWidget [

	super addKeyBindingsTo: gtkWidget.
	self addContextMenuKeyBindings: gtkWidget
]

{ #category : #building }
GtkTreeTableAdapter >> addModelTo: gtkTreeView [
	
	super addModelTo: gtkTreeView.

	gtkTreeView headersVisible: self presenter isShowingColumnHeaders.
	gtkTreeView connectDestroy: [ 
		gtkTreeView model roots: #() ].

	self addSearchTo: gtkTreeView.
	
	self recreateStore: gtkTreeView generateColumns: true.
	self configureInitialState: gtkTreeView.
	self configureDragAndDrop: gtkTreeView.
	self connectToGtkSignals: gtkTreeView.
	self connectToSpecEvents: gtkTreeView
]

{ #category : #building }
GtkTreeTableAdapter >> addSearchTo: gtkTreeView [

	self presenter isSearchEnabled ifFalse: [ ^ self ].
	
	gtkTreeView enableSearch: true.
	self presenter hasCustomSearch ifTrue: [
		gtkTreeView searchFunction: [ :key :column :iter |
			iter store: gtkTreeView model.
			self presenter 
				performSearch: (self presenter itemAtPath: iter toPathArray) 
				matching: key ] ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> collapseAll [

	self innerWidgetDo: [ :w | w collapseAll ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> collapsePath: aPath [ 

	self innerWidgetDo: [ :w | 
		w collapseToPath: aPath ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> columnCount [
	
	^ self innerWidget model numberOfColumns
]

{ #category : #'private accessing' }
GtkTreeTableAdapter >> columns [

	^ self presenter columns ifEmpty: [ { self defaultColumn } ]
]

{ #category : #building }
GtkTreeTableAdapter >> configureDragAndDrop: gtkTreeView [
	"Configure drag&drop. This is related to GtkTreeDataStore too, if you want to understand how 
	 it works you need to check for GtkTreeDataStore creation/configuration too (e.g. #newTreeStore)"
	
	self presenter dragEnabled 
		ifTrue: [ gtkTreeView enableModelDragSourceDefault ].
	self presenter dropEnabled
		ifTrue: [ gtkTreeView enableModelDragDestDefault ].

]

{ #category : #building }
GtkTreeTableAdapter >> configureInitialState: gtkWidget [

	gtkWidget headersVisible: self presenter isShowingColumnHeaders.
	gtkWidget activateOnSingleClick: self presenter activatesOnSingleClick.
	
	self presenter selection isMultipleSelection 
		ifTrue: [ gtkWidget beMultipleSelectionMode ]
		ifFalse: [ gtkWidget beSingleSelectionMode ].
	
	self presenter selection isEmpty
		ifFalse: [ self updateSelectionOf: gtkWidget ]	.
	
	self presenter contextMenu ifNotNil: [ :menu |
		self addMenu: menu to: gtkWidget ]
]

{ #category : #building }
GtkTreeTableAdapter >> connectToGtkSignals: gtkWidget [
	
	gtkWidget connectSelectionChanged: [ 
		self backendUpdatingDo: [ 
			self updatePresenterSelection ] ].
	gtkWidget connectRowActivated: [ :path | 
		self presenter doActivateAtPath: path toArray ]
]

{ #category : #building }
GtkTreeTableAdapter >> connectToSpecColumnsChangedEventTo: gtkWidget [

	self presenter whenColumnsChangedDo: [ self updateColumns ]
]

{ #category : #building }
GtkTreeTableAdapter >> connectToSpecEvents: gtkWidget [

	self presenter 
		whenShowColumnHeadersChangedDo: [ self updateColumnHeaders ];
		whenMultiSelectionChangedDo: [ self updateMultiSelection ];
		whenSelectionChangedDo: [ self updateSelection ];
		whenRootsChangedDo: [ self updateRoots ].

	self connectToSpecColumnsChangedEventTo: gtkWidget
]

{ #category : #'private accessing' }
GtkTreeTableAdapter >> defaultColumn [
			
	^ defaultColumn ifNil: [ 
		defaultColumn := SpStringTableColumn evaluated: #asString ]
]

{ #category : #private }
GtkTreeTableAdapter >> doRecreateColumns: gtkTreeView [
	| columnBuilder |

	gtkTreeView removeAllColumns.

	columnBuilder := self newColumnBuilder.
	columnBuilder view: gtkTreeView. 

	self columns do: [ :each | columnBuilder visit: each ]
]

{ #category : #private }
GtkTreeTableAdapter >> doRecreateStore: gtkTreeView [

	gtkTreeView model: (self newTreeStoreFrom: self items)
]

{ #category : #accessing }
GtkTreeTableAdapter >> expandAll [

	self innerWidgetDo: [ :w | w expandAll ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> expandPath: aPath [ 

	self innerWidgetDo: [ :w | 
		w expandToPath: aPath ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> expandRoots [ 

	self innerWidgetDo: [ :w |
		self presenter roots withIndexDo: [ :each :index |
			w expandToPath: { index } ] ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> firstSelectedPath [
	
	^ self innerWidgetDo: [ :w | w selection selectedPath ]
]

{ #category : #private }
GtkTreeTableAdapter >> initialize [

	super initialize.
	levelsAdded := Set new
]

{ #category : #testing }
GtkTreeTableAdapter >> isNonEditableRow: aRow column: aColumn [ 
	"no rows are directly editable in a component list (they can be 
	 if defined like that in the inner presenters, but it is handled different)"
	^ true
]

{ #category : #accessing }
GtkTreeTableAdapter >> itemAtPath: anArray [
 	
	^ self innerWidgetDo: [ :w | w model itemAtPath: anArray ]
]

{ #category : #private }
GtkTreeTableAdapter >> items [

	^ self model roots
]

{ #category : #'private factory' }
GtkTreeTableAdapter >> newColumnBuilder [

	^ GtkTreeTableColumnBuilder new 
		model: self presenter;
		columns: self columns;
		yourself
]

{ #category : #'private factory' }
GtkTreeTableAdapter >> newTreeStoreFrom: items [
	| store |
	
	store := GtkTreeDataStore new.
	GtkTableDataStoreColumnCollector new
		store: store;
		visitAll: self columns.

	store roots: items.
	store children: self presenter children.
	
	"configure drag&drop"
	store dragEnabled: self presenter dragEnabled.
	self presenter dropEnabled ifTrue: [ 
		store 
			dropEnabled: true;
			acceptDrop: self presenter acceptDrop ].	

	^ store
]

{ #category : #building }
GtkTreeTableAdapter >> recreateStore: gtkTreeView	generateColumns: doesGenerateColumns [

	self doRecreateStore: gtkTreeView.	
	doesGenerateColumns 
		ifTrue: [ self doRecreateColumns: gtkTreeView ].
	self addSortableColumnsTo: gtkTreeView
]

{ #category : #updating }
GtkTreeTableAdapter >> refreshList [

	self halt.
	self innerWidgetDo: [ :w | 
		w model: (self newStoreFrom: self presenter items) ]
]

{ #category : #private }
GtkTreeTableAdapter >> rowsSelected: pathColl [

	self model selection selectPaths: pathColl
]

{ #category : #accessing }
GtkTreeTableAdapter >> scrollToSelection [
	"not needed, in gtk it will always scroll to selection"
]

{ #category : #accessing }
GtkTreeTableAdapter >> selectItemIn: gtkWidget path: aPath [

	(aPath isNil or: [ aPath isEmpty ]) ifTrue: [ 
		gtkWidget selection unselectAll. 
		^ self ].

	gtkWidget expandToPath: aPath.
	gtkWidget selection selectPath: aPath.
	gtkWidget scrollToPath: aPath.

	(gtkWidget selection isSelected: aPath)
		ifFalse: [ gtkWidget selection unselectAll ].
]

{ #category : #accessing }
GtkTreeTableAdapter >> selectPath: aPath [

	self innerWidgetDo: [ :w |
		aPath 
			ifNotEmpty: [ w selection selectPath: aPath ]
			ifEmpty: [ w selection unselectAll ] ]
]

{ #category : #accessing }
GtkTreeTableAdapter >> selectedItem [
	| selectedPath |
	
	selectedPath := self firstSelectedPath.
	selectedPath ifNil: [ ^ nil ].
	selectedPath ifEmpty: [ ^ nil ].

	^ self model itemAtPath: selectedPath
]

{ #category : #accessing }
GtkTreeTableAdapter >> selectedPaths [
	
	^ self innerWidgetDo: [ :w | w allSelected ]
]

{ #category : #private }
GtkTreeTableAdapter >> store [ 

	^ self innerWidgetDo: [ :w | w model ]
]

{ #category : #private }
GtkTreeTableAdapter >> takeKeyboardFocus [

	self innerWidgetDo: [ :w |
		| needToCleanUP |
	
		needToCleanUP := self presenter selection isEmpty.
		self flag: #hack.
		"GTK has an issue when giving the focus to a List. When it gives 
		 the focus selects the first element"
		needToCleanUP 
			ifTrue: [ 
				self disconnectSelectionEventsOf: w during: [ 
					self doTakeKeyboardFocus.
					w selection unselectAll ] ]
			ifFalse: [ 
				self doTakeKeyboardFocus ] ]
]

{ #category : #releasing }
GtkTreeTableAdapter >> unsubscirbeSelectionMode [
 
	self presenter selectionMode unsubscribe: self.
]

{ #category : #releasing }
GtkTreeTableAdapter >> unsubscribe [

	| aSelection |

	self unsubscirbeSelectionMode.
	aSelection := self presenter selection observablePropertyNamed: #selection.
	aSelection
		unsubscribe: self;
		unsubscribeOuterContextReceiver: self.
	(self presenter observablePropertyNamed: #roots) unsubscribe: self.
	(self presenter observablePropertyNamed: #showColumnHeaders) 
		unsubscribe: self.
		
	super unsubscribe.
	
	self innerWidgetDo: [ :w | w model: GtkTreeDataStore new ].
	
	widget := nil.
]

{ #category : #'private updating' }
GtkTreeTableAdapter >> updateColumnHeaders [

	self innerWidgetDo: [ :w |
		w headersVisible: self presenter isShowingColumnHeaders ]
]

{ #category : #'private updating' }
GtkTreeTableAdapter >> updateColumns [

	self innerWidgetDo: [ :w |
		self 
			disconnectSelectionEventsOf: w 
			during: [ self recreateStore: w generateColumns: true ] ]
]

{ #category : #'private updating' }
GtkTreeTableAdapter >> updateMultiSelection [
	
	self innerWidgetDo: [ :w | 
		self presenter selection isMultipleSelection 
			ifTrue: [ w beMultipleSelectionMode ]
			ifFalse: [ w beSingleSelectionMode ] ]
]

{ #category : #updating }
GtkTreeTableAdapter >> updatePresenterSelection [
	
	self innerWidgetDo: [ :w |
		self rowsSelected: w allSelected ]
]

{ #category : #'private updating' }
GtkTreeTableAdapter >> updateRoots [

	self innerWidgetDo: [ :w |
		self 
			disconnectSelectionEventsOf: w 
			during: [ self recreateStore: w generateColumns: false ] ]
]

{ #category : #'private updating' }
GtkTreeTableAdapter >> updateSelection [

	self innerWidgetDo: [ :w | 
		self backendDetectCyclesDo: [
			self 
				disconnectSelectionEventsOf: w 
				during: [ self updateSelectionOf: w ] ] ]
]

{ #category : #updating }
GtkTreeTableAdapter >> updateSelectionOf: gtkWidget [

	GRunLoop defer: [ 
		self presenter selection selectedPaths 
			do: [ :selectedPath | self selectItemIn: gtkWidget path: selectedPath ] ]
]

{ #category : #building }
GtkTreeTableAdapter >> widgetClass [
	
	^ GtkTreeView
]
