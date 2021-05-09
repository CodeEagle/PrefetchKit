import UIKit

public final class PrefetchContext: NSObject {
    // MARK: - properties

    private var lock: os_unfair_lock = .init()
    /// Default is idle
    public var state: State {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _state
        }
        set {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            _state = newValue
        }
    }
     
    private var _state: State = .idle

    public var stateChangedHandler: (State) -> Void = { _ in }
    
    /// Default is 1.0
    public var leadingScreensForPrefetch: CGFloat {
        get {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return _leadingScreensForPrefetch
        }
        set {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            _leadingScreensForPrefetch = newValue
        }
    }

    private var _leadingScreensForPrefetch: CGFloat = 1

    private var observer: NSObjectProtocol?

    private weak var sc: UIScrollView?
    private lazy var uiAction: (Action) -> Void = { _ in }
    private lazy var logHandler: (String) -> Void = { _ in }

    // MARK: - life cycle methods

    init(scrollView v: UIScrollView, prefetch action: @escaping PrefetchAction) {
        super.init()
        sc = v
        observer = v.observe(\UIScrollView.contentOffset, changeHandler: { [weak self] sc, _ in
            guard let sself = self else { return }
            guard sself.state != .fetching else {
                sself.logHandler("not trigger fetching when in state: \(sself.state)")
                return
            }
            guard sself.leadingScreensForPrefetch > 0 else {
                sself.logHandler("not trigger fetching when leadingScreensForPrefetch(\(sself.leadingScreensForPrefetch))is less or equal to zero")
                return
            }

            let bounds = sc.bounds
            // no fetching for no frame == .zero scrollview
            if bounds.equalTo(CGRect.zero) {
                sself.logHandler("not trigger fetching when scrollview bounds is zero")
                return
            }

            let leadingScreens = sself.leadingScreensForPrefetch
            let contentSize = sc.contentSize
            let contentOffset = sc.contentOffset
            let isVertical = bounds.width == contentSize.width

            var viewLength: CGFloat = 0
            var offset: CGFloat = 0
            var contentLength: CGFloat = 0

            if isVertical {
                viewLength = bounds.height
                offset = contentOffset.y
                contentLength = contentSize.height
            } else { // horizontal
                viewLength = bounds.width
                offset = contentOffset.x
                contentLength = contentSize.width
            }

            // target offset will always be 0 if the content size is smaller than the viewport
            let triggerDistance = viewLength * leadingScreens
            let remainingDistance = contentLength - viewLength - offset
            guard remainingDistance <= triggerDistance, remainingDistance > 0 else {
                sself.logHandler("not trigger fetching when remainingDistance(\(remainingDistance)) is less than triggerDistance(\(triggerDistance))")
                return
            }
            sself.beginPrefetching()
            action(sc, sself)
        })
    }

    // MARK: - methods

    /// Enable PrefetchContext as [UITableView | UICollectionView]PrefetchingDataSource
    ///
    /// - Parameter action: prefetch / cancelPrefetching handler
    public func enablePrefetchingDataSource(action: @escaping (Action) -> Void) {
        asPrefetchingDataSource(enable: true, action: action)
    }

    /// disable PrefetchContext as [UITableView | UICollectionView]PrefetchingDataSource
    public func disablePrefetchingDataSource() {
        asPrefetchingDataSource(enable: false)
    }

    private func asPrefetchingDataSource(enable: Bool, action: @escaping (Action) -> Void = { _ in }) {
        if #available(iOS 10.0, *) {
            let source = enable ? self : nil
            if let tableView = sc as? UITableView {
                tableView.prefetchDataSource = source
            } else if let collectionView = sc as? UICollectionView {
                collectionView.prefetchDataSource = source
            }
        }
        uiAction = action
    }


    /// Log interal msg
    ///
    /// - Parameter handler: log handler
    public func logPipeline(_ handler: @escaping (String) -> Void) {
        logHandler = handler
    }

    public func completeFetching() { state = .completed }

    private func beginPrefetching() { state = .fetching }
}

// MARK: - extension

extension PrefetchContext: UITableViewDataSourcePrefetching {
    public func tableView(_: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        uiAction(.prefetch(indexPaths))
    }

    public func tableView(_: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        uiAction(.cancelPrefetching(indexPaths))
    }
}

@available(iOS 10.0, *)
extension PrefetchContext: UICollectionViewDataSourcePrefetching {
    public func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        uiAction(.prefetch(indexPaths))
    }

    public func collectionView(_: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        uiAction(.cancelPrefetching(indexPaths))
    }
}

// MARK: - type define

extension PrefetchContext {
    public typealias PrefetchAction = (UIScrollView, PrefetchContext) -> Void

    public enum State { case idle, fetching, completed }

    public enum Action {
        case prefetch([IndexPath])
        case cancelPrefetching([IndexPath])
    }
}

extension UIScrollView {
    /// Enable Prefetch with closure
    ///
    /// When the returned PrefetchContext is deinited or invalidated, it will stop observing
    ///
    /// - Parameter handler: prefetch handler
    /// - Returns: PrefetchContext
    public func prefetch(handler: @escaping PrefetchContext.PrefetchAction) -> PrefetchContext {
        return PrefetchContext(scrollView: self, prefetch: handler)
    }
}

