PrefetchKit
---
Prefetch kit for UIScrollview

Installation
---
##### Carthage
 `github "CodeEagle/PrefetchKit"`

Features
---
- [x] Triggered prefetch when a specific contentOffset of scrollView is reach
- [x] Can be [UITableView | UICollectionView]PrefetchingDataSource

Usage
---
```swift
import PrefetchKit

class ViewController: UIViewController {
    private var _numberOfCells = 10
    private var prefetchContext: PrefetchContext?
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: UIScreen.main.bounds)
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        return table
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        let ctx = tableView.prefetch {[weak self] (sc, ctx) in
            guard let sself = self else { return }
            DispatchQueue.main.async {
                sself._numberOfCells += 10
                sself.tableView.reloadData()
                ctx.completeFetching()
            }
        }
        ctx.enablePrefetchingDataSource(action: { (action) in
            print(action)
        })
        ctx.logPipeline { (msg) in
            print(msg)
        }
        prefetchContext = ctx
    }
}
```
