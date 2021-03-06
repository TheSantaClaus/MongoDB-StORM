//
//  Convenience.swift
//  PostgresStORM
//
//  Created by Jonathan Guthrie on 2016-10-04.
//
//

import StORM
import PerfectMongoDB
import PerfectLogger

/// Convenience methods extending the main CouchDBStORM class.
extension MongoDBStORM {

	/// Deletes one row, with an id
	/// Presumes first property in class is the id.
	public func delete() throws {
		do {
			let (_, idval) = firstAsKey()
			if (idval as! String).isEmpty {
				self.error = StORMError.error("No id specified.")
				throw error
			}
            
			let (collection, client) = try setupCollection()
			let query = BSON()
            let id = "\(idval)"
            if BSON.OID.isValidObjectId(id) {
                let oid = BSON.OID(id)
                query.append(oid: oid)
            } else {
                query.append(key: "_id", string: id)
            }
			let status = collection.remove(selector: query)
			if "\(status)" != "success" {
				LogFile.critical("MongoDB Delete error \(status)")
				throw StORMError.error("MongoDB Delete error \(status)")
			}
			close(collection, client)
		} catch {
			self.error = StORMError.error("\(error)")
			throw error
		}
	}

	/// Retrieves a document with a specified ID.
	public func get(_ id: String) throws {
		do {
			let (collection, client) = try setupCollection()

			let query = BSON()
            if BSON.OID.isValidObjectId(id) {
                query.append(oid: BSON.OID(id))
            } else {
                query.append(key: "_id", string: id)
            }

			let cursor = collection.find(
				query: query,
				skip: results.cursorData.offset,
				limit: results.cursorData.limit,
				batchSize: results.cursorData.totalRecords
			) // type MongoCursor

			// convert response into object
			try processResponse(cursor!)

			close(collection, client)
		} catch {

			self.error = StORMError.error("\(error)")
			throw error
		}
	}

	/// Retrieves a document with the ID as set in the object.
	public func get() throws {
		let (_, idval) = firstAsKey()
		let xidval = idval as! String
		if xidval.isEmpty { return }
		do {
			try get(idval as! String)
		} catch {
			throw error
		}
	}

	/// Performs a find using the selector
	/// An optional cursor:StORMCursor object can be supplied to determine pagination through a larger result set.
	/// For example, `try find(["username":"joe"])` will find all documents that have a username equal to "joe"
	public func find(_ data: [String: Any], cursor: StORMCursor = StORMCursor()) throws {
		do {
			let (collection, client) = try setupCollection()
			let findObject = BSON(map: data)
			do {
				let response = collection.find(
					query: findObject,
					skip: cursor.offset,
					limit: cursor.limit,
					batchSize: cursor.totalRecords
				)
				try processResponse(response!)
			} catch {
				throw error
			}
			close(collection, client)
		} catch {
			throw error
		}

	}


	/// Performs a findAll
	/// An optional cursor:StORMCursor object can be supplied to determine pagination through a larger result set.
	public func find(cursor: StORMCursor = StORMCursor()) throws {
		do {
			let (collection, client) = try setupCollection()
			do {
				let response = collection.find(
					skip: cursor.offset,
					limit: cursor.limit,
					batchSize: cursor.totalRecords
				)
				try processResponse(response!)
			} catch {
				throw error
			}
			close(collection, client)
		} catch {
			throw error
		}

	}


	private func processResponse(_ response: MongoCursor) throws {
		do {
			try results.rows = parseRows(response)
			results.cursorData.totalRecords = results.rows.count
			if results.cursorData.totalRecords == 1 { makeRow() }
		} catch {
			throw error
		}
	}
}
