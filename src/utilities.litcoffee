Utilities
=========

Some utility functions, mostly dealing with arrays of strings.

    Utilities =

Default comparison function for sorting arrays.

        defaultComparator: (a, b) ->
            if a > b
                1
            else if b > a
                -1
            else
                0

Convert an array to a "set". Note that this is only guaranteed to work with an array of strings.

        arrayToSet: (array) ->
            set = {}
            set[x] = 1 for x in array
            set

Convert a "set" back to an array. Note that this is only guaranteed to work with an array of strings.

        setToArray: (set) ->
            (x for x of set)

        sortedArrayWithoutDuplicates: (array, comparator = undefined) ->
            array = Utilities.setToArray(Utilities.arrayToSet(array))
            array.sort(comparator)
            array

        symmetricSortedArrayDifference: (array1, array2, comparator = undefined) ->
            set1 = Utilities.arrayToSet(array1)
            set2 = Utilities.arrayToSet(array2)
            diff = (    x for x of set1 when not set2[x]?)
                .concat(x for x of set2 when not set1[x]?)
            diff.sort(comparator)
            diff

        deferredPromise: (arg) ->
            jQuery.Deferred().resolve(arg).promise()

Export the Interface
--------------------
    (exports ? this).Utilities = Utilities
