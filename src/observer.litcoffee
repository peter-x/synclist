Observer
========

Utility that adds observer mechanism to an existing class. The following methods
are added:
 * `observe`: Register observer (provide callback function)
 * `unobserve`: Unregister the callback function
 * `clearObservers`: Unregister all observers
 * `\_callObservers`: Call all observers with given arguments (private function)
An attribute `observers` is added that contains a list of all observers.


    Observer = (theClass) ->
        override = (method, newImpl) ->
            oldImpl = theClass.prototype[method]
            if oldImpl?
                theClass.prototype[method] = (args...) ->
                    ret = newImpl.apply(@, args)
                    oldImpl.apply(@, args)
                    ret
            else
                theClass.prototype[method] = newImpl

        override 'observe', (callback) ->
            @observers ?= []
            @observers.push(callback)
            callback

        override 'unobserve', (callback) ->
            @observers ?= []
            @observers = (x for x in @observers when x != callback)
            null

        override 'clearObservers', () ->
            @observers = []

        override '_callObservers', (args...) ->
            @observers ?= []
            for x in @observers
                x(args...)
            null

Export the Interface
--------------------
    (exports ? this).Observer = Observer
