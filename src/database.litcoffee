Database Interface
======================

For now, we only support LocalStorage. Later, there will be backends for various
local and remote storage engines. In principle, it is possible to write a
database class for everything that supports storing, retrieving and listing
blobs.


LocalStorage Database
=====================

Database for HTML5 LocalStorage.

We use some arbitrary constant password. The user will be able to change it
later. Furthermore, we will also allow some means of authentication for remote
storage.

    class LocalStorageDatabase
        constructor: (@context = 'synclist',
                      @password = 'simple constant password',
                      @localStorage = window.localStorage) ->
            @changeObservers = []
            window.addEventListener 'storage', (ev) =>
                @callChangeObservers(@withoutContext(ev.key)) if @keyIsInContext(ev.key)

        save: (filename, plainData) ->
            data = Crypto.encrypt(plainData, @password)
            @localStorage[@context + '/' + filename] = data
            @callChangeObservers filename
            null

        load: (filename) ->
            data = @localStorage[@context + '/' + filename]
            Crypto.decrypt(data, @password)

        listObjects: ->
            ls = @localStorage
            for i in [0..ls.length] when @keyIsInContext ls.key(i)
                @withoutContext ls.key(i)

Register a change observer which is called for each newly created file with its
name as argument.

        onChange: (fun) ->
            @changeObservers.push fun

Remoe all objects stored under the current context. This is only used for
testing.

        clear: ->
            ls = @localStorage
            itemsToDelete = (ls.key(i) for i in [0..ls.length] when @keyIsInContext ls.key(i))
            ls.removeItem item for item in itemsToDelete

Remove all change observers.

        clearObservers: ->
            @changeObservers = []

Private Functions
-----------------

        callChangeObservers: (name) ->
            observer name for observer in @changeObservers
            null

        keyIsInContext:  (name) -> name? and name[0..@context.length] == @context + '/'

        withoutContext: (name) -> name[@context.length + 1..]

Export the Interface
--------------------
    (exports ? this).LocalStorageDatabase = LocalStorageDatabase
