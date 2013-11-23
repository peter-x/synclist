Manager
=======

The manager connects to a database, loads all items, keeps track of changes,
and merges simultaneous changes. It is a filtered view to a database through
with only the latest revisions of an item are visible.


Optimization: We do not have to actually read the items that are not the most
recent items.


    class Manager


Public Interface
----------------

        constructor: (@_database) ->

Private attributes are

 - a filename to item mapping containing all items (including obsolete
   revisions).

            @_allItems = {}

 - a mapping to retrieve the item object containing the latest revision for each
   item id.

            @_currentItems = {}

 - a flag to indicate that merging should be suppressed (until further notice)

            @_doNotMerge = true

 - a list of change observers

            @_onChangeObservers = []

            @_database.onChange (filename) =>
                @_onChangeInDatabase(filename[5...]) if filename.match /^item_/

            @_database.listObjects()
                .then((objects) =>
                    @_onChangeInDatabase filename[5...] \
                        for filename in objects when filename.match /^item_/
                    @_doNotMerge = false
                    @_doBulkMerge()
                )

Returns the list of all categories.

        getCategories: ->
            ret = {}
            ret[item.getCategory()] = 1 for id, item of @_currentItems
            k for k of ret

Get the current versions of all items as an id to item mapping.

        getItems: () ->
            # TODO we should probably create a copy
            @_currentItems

Save a new item. Note that this will also trigger the onChange-callback (see
below). It returns a promise.

        saveItem: (item) ->
            @_database.save('item_' + item.getID() + '-' + item.getRevision(), \
                            item.jsonEncode())
            .then () -> item

Register a change observer, it is called with id and item object whenever the
latest revision of an item changes.

        onChange: (fun) ->
            @_onChangeObservers.push(fun)
            null

Clear all callback observers.

        clearObservers: () ->
            @_onChangeObservers = []

Callbacks
---------

Changes can only be additions, so insert this item.

        _onChangeInDatabase: (itemname) ->
            if itemname in @_allItems
                console.log("Error: Got change notification for file we " +
                            "already know about: " + itemname)
                return
            @_database.load('item_' + itemname)
                .then((data) =>
                    item = Item.createFromJSON(itemname, data)
                    return unless item
                    id = item.getID()
                    @_allItems[itemname] = item
                    if item.isNewerThan(@_currentItems[id])
                        @_currentItems[id] = item
                        @_callOnChangeObservers(item)

                    @_checkForConflicts(id) unless @_doNotMerge
                )


Private Methods
---------------

Check the whole database for conflicts and merge them.

        _doBulkMerge: () ->
            @_checkForConflicts(id) for id of @_currentItems

Check if something needs to be merged: If there is a revision in the database
that is not in the known revisions for the specidied id, take the most recent
such revision.

        _checkForConflicts: (id) ->
            item = @_currentItems[id]
            diffs = Utilities.sortedArrayDifference(
                        @_revisionsForID(id), item.getRevisionsIncludingSelf())
            return null if diffs.length == 0
            revisionToMerge = diffs.pop()
            secondItem = @_allItems[id + '-' + revisionToMerge]
            base = item.getLatestCommonAncestor(secondItem)
            baseItem = @_allItems[id + '-' + base]
            @saveItem item.mergeWith(secondItem, baseItem)

        _callOnChangeObservers: (item) ->
            for fun in @_onChangeObservers
                fun item
            null

Get an unsorted list of all known revisions for the specified id.

        _revisionsForID: (id) ->
            for filename of @_allItems
                [thisID, revNo, revision] = filename.split('-')
                continue if thisID isnt id
                revNo + '-' + revision


Export the Interface
--------------------

    (exports ? this).Manager = Manager
