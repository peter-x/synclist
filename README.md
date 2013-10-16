Vision
======

Arbitrarily synchronizable, encrypted todo list mobile web application that supports a
multitude of storage backends.

The todo lists in this application can be synchronized with a storage provider of
your choice (a very simple HTTP REST interface is enough) and also works
offline without losing any data. Because of the synchronization features, todo
lists can be easily shared among different users and conflicts will
automatically be resolved.

If a storage backend supports CORS and has a http REST interface, it is most
probably usable by synclist. These backends include 
[remoteStorage](http://remotestorage.io/), [ownCloud](http://owncloud.org/),
or a simple WebDAV server.


Screenshots and Demo
====================

To come!

Data
====

The data is stored as a collection of versioned items, where each item has the
following properties:

 - string id
 - string revid
 - list   previous revisions
 - int    creation          (timestamp)
 - int    resolution        (timestamp)
 - int    last modification (timestamp)
 - string category
 - string text
 - float  sort position

The `id` is chosen randomly on creation, `revid` contains the revision number
(incremented on each change) plus a hash value of the json-encoding of the
object (without the hash field) - possibly after encryption.
`previous revisions` is a list of all previous revisions of this object (needed
for resolving conflicts).

Each item is stored json-encoded under the file name `id + '-' + revid`.
`id` and `revid` are omitted from the json encoding to avoid inconsistencies.

An item is considered resolved iff its resolution timestamp is nonzero.

Benefits of this Way to Store the Data
======================================

Pushing a change to the storage consists of simply adding a file to the storage.
There will be no write conflicts unless we find a hash collision. The current
version of the item is always the lexicographically largest filename that starts
with the id of the item.

Conflicts are detected whenever there is a revid for an item that is not part of
the previous revisions field. In this case, the software tries to resolve the
conflict or asks the user to decide. Once the conflict is resolved, a new
revision is created that contains the previously unknown revision in its
`previous revisions` field. Automatic conflict resolution should always be
deterministic, so that absolutely the same file will be generated.

Since no subdirectories are needed, a simple key-value storage is already
sufficient as storage engine.

Synchronization (without conflict resolution) can already be achieved by simply
copying all files, other changes will not be overwritten (assuming there are no
hash collisions).

Problems to Think About
=======================

How can changes to the storage be detected?

Large changes to the text should probably rather create a new item. Otherwise,
automatic merges can seem counter-intuitive: If Alice changes "buy chocolate" to
"buy milk" and Bob marks the item as resolved at the same time, they most
probably still need milk.


Security
========

For simplicity, access keys for remote storages are (can be) all stored locally, nobody
wants to enter passwords for a mobile application.

Items can possibly be encrypted, the encryption standard to be used is stored in
the item.


Conflict Resolution
===================

A conflict is detected if there is a revision that is not contained in the
`previous revisions` field of the most recent revision of an item.
Since there can be multiple such revisions, the newest is merged first to reduce
the number of merges needed.

From the `previous revisions` field of both items, the most recent shared
revision is determined to form the base of the merging. If there is no common
base, split the item (explained below).

Fields that can conflict and how to resolve them:

 - `previous revisions`: not a real conflict, compute the union (and sort)
 - `creation`: should actually be read-only, thus use the base
 - `resolution`: if both versions are zero or both are non-zero, take the
                 minimum, otherwise take the value that differs from the base
                 with respect to being zero or non-zero.
 - `last modification`: take the maximum
 - `category`: take the one that differs from the base, if both differ, join
               them sorted and with a comma as separator.
 - `text`: take the one that differs from the base, if it differs too much or
           if both differ, split the item.
 - `sort position`: take the one that differs from the base, and the minimum if
                    both differ. 


Splitting on Conflict
=====================

If two revisions of an item are too different (especially when the text changes
drastically), splitting the item into two could be reasonable (this needs to be
investigated). For this, an independent copy of the item is created, where the
id is the hash value of the revision that is to be cloned (the one with the
smaller revision is used). This method could result in duplicates and its
feasibility has to be determined.

 
Storage Cleanup
===============

Note that there is no way to explicitly delete items, since conflicts in deleted items
cannot be resolved. To keep the storage small, though, items are automatically
removed that are resolved and have not been modified for a specific amount of
time.
