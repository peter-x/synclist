Settings
========

User interface class to administer all settings, mostly to configure storage
backends. Provides observer mechanism where each observer is guaranteed to
receive at least one change notification. The arguments to the callback is a
list of backends with type, location (url), username, password and encryption
password.


    class Settings
        constructor: (@_database) ->
            @_storages = []
            $('#addStorage').click(() => @_populateSettingsForStorageDialog(-1))
            $('#apply-1').click(() => @_applyStorageSettings())
            @_database.observe (item) =>
                @_settingsChanged() if item == "settings"
            @_settingsChanged()

The following function will be extended by `Observer`.

        observe: (callback) ->
            callback(@_storages)

Private Methods
---------------

For each change in the database, recreate the UI.

        _settingsChanged: () ->
            @_database.loadPlain('settings')
                .then((data) =>
                    try
                        @_storages = JSON.parse data
                    catch error
                        @_storages = []
                    @_callObservers()
                    @_updateUI())

        _updateUI: () ->
            list = $('#storagelist')
            list.empty()
            for storage, index in @_storages
                do (storage, index) =>
                    $('<li></li>').append(
                        $('<a href="#" ' +
                          'data-rel="dialog" data-role="button"></a>')
                        .text(storage.location)
                        .button()
                        .click(() =>
                            @_populateSettingsForStorageDialog(index)
                            $.mobile.changePage('#settingsForStorage')))
                    .appendTo(list)

        _populateSettingsForStorageDialog: (index) ->
            data = @_storages[index] ? {}
            $('#storage-index-1').val(index)
            $('#type-1').val(data.type ? '')
            $('#location-1').val(data.location ? '')
            $('#username-1').val(data.username ? '')
            $('#password-1').val(data.password ? '')
            $('#encpassword-1').val(data.encpassword ? '')

        _applyStorageSettings: ->
            index = +$('#storage-index-1').val()
            data =
                type: $('#type-1').val()
                location: $('#location-1').val()
                username: $('#username-1').val()
                password: $('#password-1').val()
                encpassword: $('#encpassword-1').val()
            @_database.loadPlain('settings')
                .always((settings) =>
                    try
                        settings = JSON.parse settings
                    catch error
                        settings = []
                    if index == '' or index < 0 then index = settings.length
                    settings[index] = data
                    @_database.savePlain('settings', JSON.stringify settings)
                        .then(() => $('#settingsForStorage').dialog('close')))

    Observer(Settings)

Export the Interface
--------------------
    (exports ? this).Settings = Settings
