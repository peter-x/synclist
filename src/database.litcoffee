Database Interface
======================

Later, this interface can be used to access both local and remote database. For
now, we only support LocalStorage.

    databaseContext = 'synclist'


    keyIsInContext = (name) -> name? and name[0..databaseContext.length] == databaseContext + '/'

    Database =
        save: (filename, data) ->
            data = Crypto.encrypt(data, 'simple constant password')
            window.localStorage[databaseContext + '/' + filename] = data
        load: (filename) ->
            data = window.localStorage[databaseContext + '/' + filename]
            Crypto.decrypt(data, 'simple constant password')

The _contex_ is something like a specific database inside of the storage. It is
used mainly for testing on LocalStorage.

        setContext: (name) ->
            databaseContext = name

List all objects stored under the current context.

        listObjects: ->
            ls = window.localStorage
            withoutContext = (name) -> name[databaseContext.length + 1..]
            for i in [0..ls.length] when keyIsInContext ls.key(i)
                withoutContext ls.key(i)

Remoe all objects stored under the current context. This is only used for
testing.

        clear: ->
            ls = window.localStorage
            itemsToDelete = (ls.key(i) for i in [0..ls.length] when keyIsInContext ls.key(i))
            ls.removeItem item for item in itemsToDelete

Export the Interface
--------------------
    (exports ? this).Database = Database
