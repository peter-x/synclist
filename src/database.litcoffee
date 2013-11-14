Database Interface
======================

For now, we only support LocalStorage. Later, there will be backends for various
local and remote storage engines. In principle, it is possible to write a
database class for everything that supports storing, retrieving and listing
blobs.


LocalStorage Backend
====================

Database backend for HTML5 LocalStorage. This simple class can be used to
illustrate the interface between the general Database and the specific backend.
The only complication is that it filters LocalStorage keys that do not start
with a specific string, called the context.

    class LocalStorageBackend
        constructor: (@_changeNotification, config = {context: 'synclist'}) ->
            @_context = config.context
            @_localStorage = window.localStorage
            window.addEventListener 'storage', (ev) =>
                @_changeNotification(@_withoutContext(ev.key)) if @_keyIsInContext(ev.key)

        list: () ->
            ls = @_localStorage
            Utilities.deferredPromise(
                for i in [0..ls.length] when @_keyIsInContext ls.key(i)
                    @_withoutContext ls.key(i)
            )

        get: (key) ->
            Utilities.deferredPromise(
                @_localStorage[@_context + '/' + key]
            )

        put: (key, data) ->
            Utilities.deferredPromise(
                @_localStorage[@_context + '/' + key] = data

LocalStorage does not get a change notification for its own changes, so we call
the observers manually.

                @_changeNotification(key)
            )

The following function is only for testing purposes and should not be
implemented on other backends.

        @clearContext: (context) ->
            ls = window.localStorage
            itemsToDelete = (ls.key(i) for i in [0..ls.length - 1] \
                    when ls.key(i)[0..context.length] == context + '/')
            ls.removeItem item for item in itemsToDelete

Private Functions
-----------------

These are not part of the storage backend interface.

        _keyIsInContext:  (name) -> name? and name[0..@_context.length] == @_context + '/'

        _withoutContext: (name) -> name[@_context.length + 1..]


Database
========

The database takes care of encrypting and decrypting data and uses one of the
various backends to actually store the data. For now, we use some arbitrary
constant password, the user will of course be able to change it later.
Furthermore, we will also allow some means of authentication for remote storage.

    class Database
        constructor: (Backend, backendConfig,
                      @_password = 'simple constant password') ->
            @_changeObservers = []
            @_backend = new Backend(((key) => @_callChangeObservers key), \
                                    backendConfig)

        save: (filename, plainData, encryption=true) ->
            @_backend.put(filename, if encryption
                        Crypto.encrypt(plainData, @_password)
                    else
                        plainData)
                .then(() => filename)

        load: (filename, encryption=true) ->
            @_backend.get(filename)
                .then((data) =>
                    return Utilities.rejectedDeferredPromise() unless data?
                    if encryption
                        Crypto.decrypt(data, @_password)
                    else
                        data)

The next two functions explicitly return the plain data without encrypting /
decrypting.

        savePlain: (filename, plainData) ->
            @save(filename, plainData, false)

        loadPlain: (filename) ->
            @load(filename, false)

        listObjects: ->
            @_backend.list()

Register a change observer which is called for each newly created file with its
name as argument.

        onChange: (fun) ->
            @_changeObservers.push fun

Remove all change observers.

        clearObservers: ->
            @_changeObservers = []

Private Functions
-----------------

        _callChangeObservers: (name) ->
            observer name for observer in @_changeObservers
            null


Export the Interface
--------------------
    (exports ? this).Database = Database
    (exports ? this).LocalStorageBackend = LocalStorageBackend
