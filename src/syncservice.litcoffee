Sync Service
============

A very simple service that makes sure that each object that lives in one
database is copied to all other databases. Merging conflicting changes is
handeled in the `Manager`.
It provides an observer mechanism than combines the callback messages of the
synchronization helpers (see below) in the obvious way.

    class SyncService

        constructor: (@_settings, @_database) ->
            @_combinedState = 0
            @_errorMessage = undefined
            @_synchronizers = []
            @_synchronizerObserver = () =>
                @_combinedState = 0
                @_errorMessage = undefined
                for s in @_synchronizers
                    state = switch s.getState()
                        when 'error' then 2
                        when 'synchronizing' then 1
                        else 0
                    @_combinedState = Math.max(@_combinedState, state)
                    if state == 2 then @_errorMessage = s.getErrorMessage()
                @_combinedState = ['waiting', 'synchronizing',
                                   'error'][@_combinedState]

                @_callObservers(@_combinedState, @_errorMessage)

            @_settings.observe (remoteSettings) =>
                if console?
                    console.log "Syncservice: Change in settings detected"

                s.destructor() for s in @_synchronizers
                @_synchronizers = []
                for dbSetting in remoteSettings
                    db = @_settingToDb dbSetting
                    if db
                        sync = new Synchronizer(@_database, db)
                        sync.observe @_synchronizerObserver
                        @_synchronizers.push sync
                @_synchronizerObserver()

        getState: () -> @_combinedState

        getErrorMessage: () -> @_erroMessage

Request all synchronizers to do a full synchronization, which means that a list
of all files on all databases is requested and differences in these lists are
removed by transferring the files. Returns a deferred object which combines all
results, i.e. it is successful if and only if all synchronizations were
successful.

        fullSync: () ->
            s.fullSync() for s in @_synchronizers

        _settingToDb: (setting) ->
            if setting.type == 'LocalStorage'
                dbClass = LocalStorageBackend
                options = {context: setting.location}
                encpassword = setting.encpassword
                new Database(dbClass, options, encpassword)
            else if setting.type == 'RemoteStorage'
                dbClass = RemoteStorageBackend
                options = {user: setting.location}
                encpassword = setting.encpassword
                new Database(dbClass, options, encpassword)
            else if setting.type == 'WebDAV'
                dbClass = WebDavBackend
                options = {url: setting.location, \
                           username: setting.username, \
                           password: setting.password}
                encpassword = setting.encpassword
                new Database(dbClass, options, encpassword)
            else
                null

        observe: (callback) ->
            callback(@_combinedState, @_errorMessage)

    Observer(SyncService)

Synchronizer Helper
-------------------

This class handles the synchronization between the local database and a single
other database, in both directions. Upon construction, it tries to synchronize
everything and then reacts on changes in both databases.
It provides an observer mechanism to report transfers and error states. The
possible callback arguments correspond to the internal states
'synchronizing', 'waiting', 'destroyed' and 'error'. A synchronizer never
recovers from the error state, it has to be recreated.

    class Synchronizer
        constructor: (@_sourceDB, @_targetDB) ->
            @_state = 'waiting'
            @_transfers = 0
            @_errorMessage = ''

            @_changesToIgnore = {}
            @_active = true
            @_sourceDB.observe @_sourceObserver = (filename) =>
                if @_changesToIgnore[filename]?
                    delete @_changesToIgnore[filename]
                else
                    @_changesToIgnore[filename] = 1
                    @_transferTo filename

            @_targetDB.observe @_targetObserver = (filename) =>
                if @_changesToIgnore[filename]?
                    delete @_changesToIgnore[filename]
                else
                    @_changesToIgnore[filename] = 1
                    @_transferFrom filename
            @fullSync()

        destructor: () ->
            @clearObservers()
            @_state = 'destroyed'
            @_active = false
            @_sourceDB.unobserve @_sourceObserver
            @_targetDB.unobserve @_targetObserver

        fullSync: () ->
            return unless @_active
            @_checkState(1)
            @_sourceDB.listObjects()
            .then (sourceList) =>
                return unless @_active
                @_targetDB.listObjects()
                .then (targetList) =>
                    return unless @_active
                    toTransferTo = Utilities.sortedArrayDifference(sourceList,
                                                                   targetList)
                    @_transferTo(x) for x in toTransferTo
                    toTransferFrom = Utilities.sortedArrayDifference(targetList,
                                                                     sourceList)
                    @_transferFrom(x) for x in toTransferFrom
            .done () =>
                @_checkState(-1)
            .fail (error) =>
                @_setError(error)

        _transferTo: (filename) ->
            @_transfer(filename, @_sourceDB, @_targetDB)

        _transferFrom: (filename) ->
            @_transfer(filename, @_targetDB, @_sourceDB)

        _transfer: (filename, db1, db2) ->
            return unless @_active and filename.match /^item_/
            if console?
                console.log "Syncservice: Transferring " + filename + "."
            @_checkState(1)
            db1.load(filename)
            .then (data) =>
                return unless data and @_active
                db2.save(filename, data)
            .done () =>
                @_checkState(-1)
            .fail (error) =>
                @_setError(error)

        getState: () ->
            @_state

        getErrorMessage: () ->
            @_errorMessage

Adjust the number of currently executing file transfers, set the state
accordingly and report to the observers if it changed.

        _checkState: (transfers) ->
            return if transfers == 0 or not @_active
            @_transfers += transfers
            @_state = if @_transfers == 0 then 'waiting' else 'synchronizing'
            @_callObservers(@_state)

        _setError: (error) ->
            @_active = false
            @_state = 'error'
            @_errorMessage = error
            @_callObservers(@_state, @_errorMessage)

    Observer(Synchronizer)

Export the Interface
--------------------

    (exports ? this).SyncService = SyncService
