import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Machine.test(filename: "TST8080", expectedCycles: 4924)
        //Machine.test(filename: "~/Documents/CPUTEST.COM", expectedCycles: 255653383)
    }

    override var representedObject: Any? {
        didSet {}
    }
}

