Application
===========

This is the main file that ties everything together. It constructs the Database,
the Manager and the UserInterface and connects them.


    class Application

        constructor: () ->
            @_database = new Database(LocalStorageBackend, {context: 'synclist'})
            @_settings = new Settings(@_database)
            @_manager = new Manager(@_database)
            @_userInterface = new UserInterface(@_manager)

Export the Interface and create the Singleton
---------------------------------------------

    (exports ? this).Application = Application
    jQuery ->
        window.ApplicationInstance = new Application()
        
