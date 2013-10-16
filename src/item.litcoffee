Item Object
===========

This is the basic data structure that describes a list item. This class handles
all transformations that are necessary to store the data in a database and also
merges conflicting revisions.

    class Item

Constructors and Factory Functions
----------------------------------

The constructor should not be called from outside. Please use the factory
functions `@createNew` and `@createFromJSON`.
        
        constructor: (@id, @revision = '', @revisions = [],
                      @creation = 0, @resolution = 0, @modification = 0,
                      @category = '', @text = '', @position = 0) ->

Creates a new `Item` object from a filename consisting of the id, the revision
number and the hash (for example `ag76utHefufiuepUi-17-Tefu0thdiyeH`) and the
decrypted file contents, i.e. a JSON string. On error, this function returns
null.
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

This function creates a new item and automatically generates an id for it.
It returns null on error.

        @createNew: (text, category = '', position = 0) ->
            if not (typeof text is typeof category is 'string' and
                                   typeof position is 'number')
                null
            else
                new Item(@generateID(), '', [],
                         +new Date, 0, +new Date,
                         category, text, position)

Getters and Setters
-------------------

Note that all setters immediately trigger a "save to database".

        getCreated: -> @creation

        isResolved: -> @resolution > 0
        getResolved: -> @resolution
        setResolved: ->
            @resolution = +new Date
            @adjustModificationAndSave()

        getCategory: -> @category
        setCategory: (@category) ->
            @adjustModificationAndSave()

        getText: -> @text
        setText: (@text) ->
            @adjustModificationAndSave()

        getPosition: -> @position
        setPosition: (@position) ->
            @adjustModificationAndSave()

Merge function
--------------

Compute a new `Item` that is a merged version of this and `item`. `base` is the
latest common ancestor of both items.
        mergeWith: (item, base) ->
            throw "Not yet implemented"
            new Item(@id, @sortRevisions(@revision, item.revision)[1],
                          @sortRevisions(@revisions..., item.revisions...),
                     creation, resolution, modification,
                     text, category, position)

Private Helper Functions
----------------------------

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

Create a new random id.
        @generateID: (length = 22) ->
            characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
            (characters[Math.floor(Math.random() * characters.length)] for i in [1..length]).join('')

Compute the incremented revision string.
        getIncrementedRevision: ->
            rev = @revision || '0-'
            revisionNumber = +(@revision.split '-')[0]
            "#{ revisionNumber + 1 }-#{ @getHash() }"

Compute the hash part of the revision string.
        getHash: ->
            Crypto.hash @jsonEncode()

Return sorted union of revisions
        @sortRevisions: (revisions...) ->
            revs = {}
            revs[r] = 1 for r in revisions
            revs = [r for r in revs]
            revs.sort(@revisionComparator)
            revs

Compute the JSON encoding of the item.
        jsonEncode: ->
            @revisions = @sortRevisions(@revisions...)
            JSON.stringify {
                revisions: @revisions,
                creation: @creation, resolution: @resolution,
                modification: @modification,
                category: @category, text: @text,
                position: @position}

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

