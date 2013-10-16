Item Object
===========

An `Item` is the basic data structure, it describes a list entry. This class
handles all transformations that are necessary to store the data in a database
and also merges conflicting revisions.

    class Item

Constructors and Factory Functions
----------------------------------

The constructor should only be used internally. Please use the factory
functions `@createNew` and `@createFromJSON`.
        
        constructor: (@id, @revision = '', @revisions = [],
                      @creation = 0, @resolution = 0, @modification = 0,
                      @category = '', @text = '', @position = 0) ->

Creates a new `Item` object from a filename consisting of the id, the revision
number and the hash (for example `ag76utHefufiuepUi-17-Tefu0thdiyeH`) and the
decrypted file contents, i.e. a JSON string. On error, this function returns
null, it does not save the Item to the database.
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
            m = /^([a-zA-Z0-9]+)-([1-9][0-9]*-[a-zA-Z0-9]+)$/.match filename
            if not m
                return null
            [id, revision] = m

            new Item(id, revision, data.revisions[...]
                     data.creation, data.resolution, data.modification
                     data.category, data.text,
                     data.position)

This factory function creates a new item and automatically generates an id for
it. The item is immediately saved to the databes.
The function returns null on error.

        @createNew: (text, category = '', position = 0) ->
            if not (typeof text is typeof category is 'string' and
                                   typeof position is 'number')
                null
            else
                item = new Item(@generateID(), '', [],
                                +new Date, 0, +new Date,
                                category, text, position)
                item.save
                item

Getters and Setters
-------------------

Note that all setters immediately trigger a "save to database".

Creation timestamp.
        getCreated: -> @creation

The resolution ('checked' state) and its timestamp.
        isResolved: -> @resolution > 0
        getResolved: -> @resolution
        setResolved: ->
            @resolution = +new Date
            @adjustModificationAndSave()

The Category, an arbitrary string.
        getCategory: -> @category
        setCategory: (@category) -> @adjustModificationAndSave()

The main text, also an arbitrary string.
        getText: -> @text
        setText: (@text) -> @adjustModificationAndSave()

The position inside its category, an arbitrary number.
        getPosition: -> @position
        setPosition: (@position) -> @adjustModificationAndSave()

Comparison Function
-------------------

        @comparator: (a, b) -> return a.position - b.position

Merge function
--------------

Compute a new `Item` that is a merged version of this and `item`. `base` is the
latest common ancestor of both items. The new item is immediately saved.
        mergeWith: (item, base) ->
The merge strategy is as follows:

 - revision: Take the higher revision (it will be incemented just before
   saving).
            revision = @sortRevisions(@revision, item.revision)[1]

 - revisions: Compute the union of everything known.
            revisions = @sortRevisions(@revision, item.revision,
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
                     text, category, position)

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
                i += 1 while @revisions[i] is item.revisions[i]
                @revisions[i - 1]

Private Helper Functions
------------------------

Adjust modification time and save to the database.
        adjustModificationAndSave: ->
            @modification = +new Date
            @save()

Save the item to the database. This function does not handle conflict resolution
or merging, it will be done afterwards by the merge service.
        save: ->
            @revisions.push(@revision)
            @revision = @getIncementedRevision()
            throw 'Not yet implemented.'

Compute the incremented revision string of this object.
        getIncrementedRevision: ->
            rev = @revision || '0-'
            revisionNumber = +(@revision.split '-')[0]
            "#{ revisionNumber + 1 }-#{ @getHash() }"

Compute the hash part of the revision string of this object.
        getHash: ->
            Crypto.hash @jsonEncode()

Compute the JSON encoding of the item.
        jsonEncode: ->
            @revisions = @sortRevisions(@revisions...)
            JSON.stringify {
                revisions: @revisions,
                creation: @creation, resolution: @resolution,
                modification: @modification,
                category: @category, text: @text,
                position: @position}


Private and Static Helper Functions
-----------------------------------

Create and return a new random id.
        @generateID: (length = 22) ->
            characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
            (characters[Math.floor(Math.random() * characters.length)] for i in [1..length]).join('')

Return sorted list of revisions without duplicates.
        @sortRevisions: (revisions...) ->
            revs = {}
            revs[r] = 1 for r in revisions
            revs = [r for r in revs]
            revs.sort(@revisionComparator)
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

