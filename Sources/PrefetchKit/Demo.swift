#if DEBUG
import UIKit
import SwiftUI

class ViewController: UIViewController {
    private static var fixedLength = 10
    private var _numberOfCells = ViewController.fixedLength
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
            print("prefech")
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

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _numberOfCells
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell")!
        cell.textLabel?.text = "\(indexPath.row) \(indexPath.row > ViewController.fixedLength ? "[prefetch data]" : "")"
        return cell
    }
}
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300
    }
}

struct DemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        ViewController()
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
    }
    
}

struct DemoView_Preview: PreviewProvider {
    static var previews: some View {
        DemoView()
    }
}
#endif
