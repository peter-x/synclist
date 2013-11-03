Item Object
===========

An `Item` is the basic data structure, it describes a list entry. This class
automatically generates revision strings and can resolve conflicts. Each
instance of this class is immutable and it is the user's responsibility to store
and retreive all objects.

    class Item

Constructors and Factory Functions
----------------------------------

The constructor should only be used internally. Please use the factory
functions `@createNew` and `@createFromJSON`.
        
        constructor: (@id, @revision = '', @revisions = [],
                      @creation = 0, @resolution = 0, @modification = 0,
                      @category = '', @text = '', @position = 0) ->

Creates an `Item` object from a filename consisting of the id, the revision
number and the hash (for example `ag76utHefufiuepUi-17-Tefu0thdiyeH`) and the
decrypted file contents, i.e. a JSON string. The loaded data is not modified
(i.e. no new revision string is generated). On error, this function returns null.

        @createFromJSON: (filename, text) ->
            try
                data = JSON.parse text
            catch error
                return null

            if typeof filename isnt 'string' or typeof data isnt 'object'
                return null
            if not (typeof data.creation is typeof data.resolution is
                    typeof data.modification is typeof data.position is
                    'number' and
                    typeof data.category is typeof data.text is 'string')
                return null
            try
                for rev in data.revisions[...]
                    if typeof rev isnt 'string'
                        return null
            catch error
                return null
            m = /^([a-zA-Z0-9]+)-([1-9][0-9]*-[a-zA-Z0-9]+)$/.exec filename
            if not m
                return null
            [filename, id, revision] = m

            new Item(id, revision, data.revisions[...]
                     data.creation, data.resolution, data.modification
                     data.category, data.text,
                     data.position)

This factory function creates a new item and automatically generates an id and
first revision for it. The function returns null on error.

        @createNew: (text, category = '', position = 0) ->
            if not (typeof text is typeof category is 'string' and
                                   typeof position is 'number')
                null
            else
                timestamp = (+new Date) / 1000.0
                item = new Item(Item.generateID(), '', [],
                                timestamp, 0, timestamp,
                                category, text, position)
                item.updateRevision()

Getters and Setters
-------------------

Note that the setters do not modify the `Item` but return a new one (with
incremented revision number).

ID

        getID: -> @id

Current revision

        getRevision: -> @revision

List of known merged revisions plus the current revision.

        getRevisionsIncludingSelf: -> [@revision].concat(@revisions)

Creation timestamp.

        getCreated: -> @creation

The resolution ('checked' state) and its timestamp.

        isResolved: -> @resolution > 0
        getResolved: -> @resolution
        setResolved: -> @changedCopy( -> @resolution = (+new Date) / 1000.0)

The Category, an arbitrary string.

        getCategory: -> @category
        setCategory: (category) -> @changedCopy( -> @category = category)

The main text, also an arbitrary string.

        getText: -> @text
        setText: (text) -> @changedCopy( -> @text = text)

The position inside its category, an arbitrary number.

        getPosition: -> @position
        setPosition: (position) -> @changedCopy( -> @position = position)

Compute the JSON encoding of the item.

        jsonEncode: ->
            @revisions = Item.sortRevisions(@revisions...)
            JSON.stringify {
                revisions: @revisions,
                creation: @creation, resolution: @resolution,
                modification: @modification,
                category: @category, text: @text,
                position: @position}


Comparison Function
-------------------

Compare two items by position.

        @comparator: (a, b) -> a.position - b.position

Compare two items by their revision. Returns `true` if otherItem does not exist.

        isNewerThan: (otherItem) ->
            not otherItem? or Item.revisionComparator(@revision, otherItem.revision) > 0

Merge function
--------------

Compute a new `Item` that is a merged version of this and `item`. `base` is the
latest common ancestor of both items.

        mergeWith: (item, base) ->

The merge strategy is as follows:

 - revision: Take the higher revision (it will be incemented just before
   saving).

            revision = Item.sortRevisions(@revision, item.revision)[1]

 - revisions: Compute the union of everything known.

            revisions = Item.sortRevisions(@revision, item.revision,
                                       @revisions..., item.revisions...)

 - creation: This is actually read-only, so take the base.

            creation = base.creation

 - resolution:

            resolution =

   If both resolution timestamps are equal with respect to their
   truth value, take the earlier one.

                if (item.resolution > 0) is (@resolution > 0)
                    Math.min(item.resolution, @resolution)

   Otherwise, take the one that differs from the base.

                else if (item.resolution > 0) isnt (base.resolution > 0)
                    item.resolution
                else
                    @resolution

 - modification: Take the maximum.

            modification = Math.max(@modification, item.modification)

 - text:

            text =

   If both are equal, take anything.

                if @text == item.text
                    @text

   If only one differs from base, take that one.

                else if @text == base.text
                    item.text
                else if item.text == base.text
                    @text

   Now the really complicated case: both text differ. It would probably be best
   to create two independent copies of the item. This could alse be a viable
   solution if there are large changes in the text and something else changed in
   the other version. This idea will perhaps be implemented in a later version.

                else if @text < item.text
                    @text + ', ' + item.text
                else
                    item.text + ', ' + @text

 - category: Here we use exactly the same strategy we used for the text.

            category =
                if @category == item.category
                    @category
                else if @category == base.category
                    item.category
                else if item.category == base.category
                    @category
                else if @category < item.category
                    @category + ', ' + item.category
                else
                    item.category + ', ' + @category

 - position: Use the one that differs from base and the minimum if both differ.

            position =
                if @position is base.position
                    item.position
                else if item.position is base.position
                    @position
                else
                    Math.min(@position, item.position)

            new Item(@id, revision, revisions,
                     creation, resolution, modification,
                     category, text, position)
                .updateRevision()

Determine the latest common ancestor revision of two items. Returns `undefined`
if they do not share an ancestor. Note that one of the two items itself can be
an ancestor of the other.

        getLatestCommonAncestor: (item) ->
            if @revision is item.revision or @revision in item.revisions
                @revision
            else if item.revision in @revisions
                item.revision
            else
                len = Math.min(@revisions.length, item.revisions.length)
                i = 0
                i += 1 while i < len and @revisions[i] is item.revisions[i]
                if i == 0
                    null
                else
                    @revisions[i - 1]

Private Helper Functions
------------------------

Return a copy of this `Item`, where the function given as argument is applied
(and of course revisions are updated).

        changedCopy: (mod) ->
            item = new Item(@id, @revision, @revisions[...],
                            @creation, @resolution, @modification,
                            @category, @text, @position)
            mod.call(item)
            item.adjustModificationAndUpdateRevision()

Adjust modification time and update `@revision` and `@revisions` to the database.

        adjustModificationAndUpdateRevision: ->
            @modification = (+new Date) / 1000.0
            @updateRevision()

Update `@revision` and `@revisions`: Push the current revision to `@revisions`,
sort this array, increment the revision number and generate a new revision hash.

        updateRevision: ->
            @revisions.push(@revision) if @revision.length > 0
            data = @jsonEncode()
            @revision = @getIncrementedRevision data
            this

Compute the incremented revision string of this object.

        getIncrementedRevision: (data) ->
            rev = @revision || '0-'
            revisionNumber = +(rev.split '-')[0]
            "#{ revisionNumber + 1 }-#{ Crypto.hash data }"


Private and Static Helper Functions
-----------------------------------

Create and return a new random id.

        @generateID: (length = 22) ->
            characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
            (characters[Math.floor(Math.random() * characters.length)] for i in [1..length]).join('')

Public and Static Helper Functions
-----------------------------------

Return sorted list of revisions without duplicates.

        @sortRevisions: (revisions...) ->
            revs = {}
            revs[r] = 1 for r in revisions
            revs = (r for r of revs)
            revs.sort(Item.revisionComparator)
            revs

Comparison function for revision strings: First compare the integer revision
number and then the string.

        @revisionComparator: (a, b) ->
            [aNum, aRev] = a.split '-'
            [bNum, bRev] = b.split '-'
            if +aNum != +bNum
                aNum - bNum
            else if aRev > bRev
                1
            else if bRev > aRev
                -1
            else
                0

Export the Item
---------------
    (exports ? this).Item = Item
