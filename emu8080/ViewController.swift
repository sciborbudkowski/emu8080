import Cocoa

class ViewController: NSViewController {

    @IBAction func onClick(_ sender: Any) {
        Machine.test(filename: "TST8080", expectedCycles: 4924)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {}
    }
}

