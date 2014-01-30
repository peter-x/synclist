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


WebDav Backend
==============

Very simple WebDav database backend, it depends on jQuery to make the ajax
requests. The config argument should have tho following attributes:

 - url: e.g. `https://example.com/path/to/webdav/`
 - user: username
 - password: password for basic authentication

    class WebDavBackend
        constructor: (@_changeNotification, config) ->
            @_url = config.url
            @_url += '/' if @_url[@_url.length - 1] != '/'
            @_username = config.username
            @_password = config.password
            authString = 'Basic ' + Crypto.utf8ToBase64(@_username + ':' + @_password)
            @_authHeader = {Authorization: authString}
            # TODO add timeout to periodically check for changes

        list: () ->
            [requestHost, requestPath] = @_url.match(/^(https?:\/\/[^\/]*)(\/.*)/)[1..]
            ajaxOptions =
                url: @_url
                type: 'PROPFIND',
                contentType: 'application/xml',
                headers: {Depth: '1', Authorization: @_authHeader['Authorization']},
                data: '<?xml version="1.0" encoding="utf-8" ?>' + \
                                     '<propfind xmlns="DAV:"><prop></prop></propfind>'
            jQuery.ajax(ajaxOptions)
            .pipe((data) ->
                entries = []
                jQuery('d\\:response, response', data).each((i, el) ->
                    elPath = jQuery('d\\:href, href', el).text().replace(/^https?:\/\/[^\/]*/, '')
                    if elPath[..requestPath.length - 1] == requestPath
                        el = elPath[requestPath.length..]
                        entries.push(el) if (el != '' and el != '/')
                )
                entries
            )
            # TODO error condition

        get: (key) ->
            jQuery.ajax({url: @_url + '/' + key, dataType: 'text',\
                         headers: @_authHeader})

        put: (key, data) ->
            ajaxOpts =
                url: @_url + '/' + key,
                data: data,
                contentType: '',
                type: 'PUT',
                dataType: 'text'
                headers: @_authHeader

            jQuery.ajax(ajaxOpts)
                .then( => @_changeNotification(key))


RemoteStorage Backend
=====================

RemoteStorage backend ( http://remotestorage.io ) - due to its requirement to
authenticate via OAuth, it is a bit more complex (but of course has improved
security).
The config argument should have tho following attributes:

 - user: username@service.com

The backend tries to login automatically, which can cause a page change because
of OAuth.

    class RemoteStorageBackend
        constructor: (@_changeNotification, config) ->
            @_user = config.user
            @_rs = remoteStorage
            @_rs.access.claim('synclist', 'rw')
            @_rs.connect(@_user)

        list: () ->
            d = jQuery.Deferred()
            if not @_rs.connected
                d.reject()
            else
                @_rs.get('/synclist/')
                    .then(((code, result, mimetype) ->
                                d.resolve(Utilities.setToArray result)),
                          () -> d.reject())
            d.promise()

        get: (key) ->
            d = jQuery.Deferred()
            if not @_rs.connected
                d.reject()
            else
                @_rs.get('/synclist/' + key)
                    .then(((code, data, mimetype, revision) -> d.resolve(data)),
                          () -> d.reject())
            d.promise()

        put: (key, data) ->
            d = jQuery.Deferred()
            if not @_rs.connected
                d.reject()
            else
                @_rs.put('/synclist/' + key, data, 'text/plain')
                    .then((() -> d.resolve()),
                          () -> d.reject())
            d.promise()

Database
========

The database takes care of encrypting and decrypting data and uses one of the
various backends to actually store the data. Furthermore, we will also allow
some means of authentication for remote storage. The database provides a change
observer mechanism via the methods `observe` and `unobserve`.

    class Database
        constructor: (Backend, backendConfig, @_password = null) ->
            @_backend = new Backend(((key) => @_callObservers key), \
                                    backendConfig)

        save: (filename, plainData) ->
            @_backend.put(filename, Crypto.encrypt(plainData, @_password))
                .then(() => filename)

        load: (filename) ->
            @_backend.get(filename)
                .then((data) =>
                    if data?
                        Crypto.decrypt(data, @_password)
                    else
                        Utilities.rejectedDeferredPromise())

        listObjects: ->
            @_backend.list()

Add the observer mechanism to the class.

    Observer(Database)

Export the Interface
--------------------
    (exports ? this).Database = Database
    (exports ? this).LocalStorageBackend = LocalStorageBackend
    (exports ? this).WebDavBackend = WebDavBackend
    (exports ? this).RemoteStorageBackend = RemoteStorageBackend
