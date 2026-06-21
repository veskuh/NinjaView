.pragma library

// Helper to get total count from different model types
function getModelCount(model) {
    if (!model) return 0
    if (model.count !== undefined) return model.count
    if (typeof model.rowCount === 'function') return model.rowCount()
    return 0
}

// Helper to get path from different model types
function getPath(model, idx, loggingEnabled, logger) {
    if (!model) {
        if (loggingEnabled && logger && logger.loggingEnabled) {
            logger.log("getPath(" + idx + ") FAILED: model is null", "Model")
        }
        return ""
    }
    if (idx < 0) return ""
    
    let rowCount = getModelCount(model)
    if (idx >= rowCount) {
        if (loggingEnabled && logger && logger.loggingEnabled) {
            logger.log("getPath(" + idx + ") FAILED: out of bounds (count=" + rowCount + ")", "Model")
        }
        return ""
    }
    
    let path = ""
    try {
        // Try C++ model helper first
        if (typeof model.getRawPath === 'function') {
            path = model.getRawPath(idx)
        } else if (typeof model.get === 'function') {
            // Fallback for QML ListModel
            let item = model.get(idx)
            if (item && item.rawPath !== undefined && item.rawPath !== null) {
                path = item.rawPath.toString()
            }
        } else if (typeof model.index === 'function' && typeof model.data === 'function') {
            // Fallback for standard QAbstractItemModel
            let qidx = model.index(idx, 0)
            if (qidx) {
                let role = (typeof Qt !== 'undefined') ? Qt.UserRole + 3 : 259 // RawPathRole
                let data = model.data(qidx, role)
                if (data !== undefined && data !== null) {
                    path = data.toString()
                }
            }
        }
    } catch (e) {
        if (loggingEnabled && logger && logger.loggingEnabled) {
            logger.log("getPath(" + idx + ") EXCEPTION resolving path: " + e, "Model")
        }
    }
    
    return path
}

function isFolder(model, idx) {
    if (!model || idx < 0) return false
    
    let rowCount = getModelCount(model)
    if (idx >= rowCount) return false

    try {
        if (typeof model.isFolder === 'function') {
            return model.isFolder(idx)
        }
        if (typeof model.index === 'function' && typeof model.data === 'function') {
            let qidx = model.index(idx, 0)
            if (qidx) {
                let role = (typeof Qt !== 'undefined') ? Qt.UserRole + 4 : 260 // IsFolderRole
                let data = model.data(qidx, role)
                if (data !== undefined && data !== null) {
                    return data
                }
            }
        }
    } catch (e) {
        // ignore
    }
    return false
}

function isVideo(model, idx) {
    if (!model || idx < 0) return false
    
    let rowCount = getModelCount(model)
    if (idx >= rowCount) return false

    try {
        if (typeof model.isVideo === 'function') {
            return model.isVideo(idx)
        }
        if (typeof model.index === 'function' && typeof model.data === 'function') {
            let qidx = model.index(idx, 0)
            if (qidx) {
                let role = (typeof Qt !== 'undefined') ? Qt.UserRole + 5 : 261 // IsVideoRole
                let data = model.data(qidx, role)
                if (data !== undefined && data !== null) {
                    return data
                }
            }
        }
    } catch (e) {
        // ignore
    }
    return false
}

function getNextImageIndex(model, idx) {
    if (!model) return -1
    let modelCount = getModelCount(model)
    let next = idx + 1
    while (next < modelCount && isFolder(model, next)) {
        next++
    }
    return next < modelCount ? next : -1
}

function getPrevImageIndex(model, idx) {
    if (!model) return -1
    let prev = idx - 1
    while (prev >= 0 && isFolder(model, prev)) {
        prev--
    }
    return prev >= 0 ? prev : -1
}
