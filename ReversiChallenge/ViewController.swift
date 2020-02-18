import UIKit
import CleanReversi
import CleanReversiAsync
import CleanReversiAI
import CleanReversiApp
import CleanReversiGateway

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView!
    
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    private var messageDiskSize: CGFloat! // to store the size designated in the storyboard
    
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!
    
    private var gameController: GameController!
    private var gameSaver: GameSaver!
    var board: Board = Board(width: 8, height: 8) // required by `GameControllerBoardAnimationDelegate`
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messageDiskSize = messageDiskSizeConstraint.constant
        gameSaver = GameSaver(delegate: self)
        gameController = GameController(delegate: self, saveDelegate: gameSaver, strategyDelegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        try? gameController.start()
    }
}

// MARK: Inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        gameController.reset()
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)
        gameController.setPlayer(.init(index: sender.selectedSegmentIndex), of: side)
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        try? gameController.placeDiskAt(x: x, y: y)
    }
}

// MARK: Delegates

extension ViewController: GameControllerDelegate, GameControllerBoardAnimationDelegate {
    func updateMessage(_ message: GameController.Message, animated: Bool) {
        switch message {
        case .turn(let side):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side
            messageLabel.text = "'s turn"
        case .result(winner: .some(let winner)):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = winner
            messageLabel.text = " won"
        case .result(winner: .none):
            messageDiskSizeConstraint.constant = 0
            messageLabel.text = "Tied"
        }
    }
    
    func updateDiskCountsOf(dark darkDiskCount: Int, light lightDiskCount: Int, animated: Bool) {
        countLabels[Disk.dark.index].text = darkDiskCount.description
        countLabels[Disk.light.index].text = lightDiskCount.description
    }
    
    func updatePlayer(_ player: GameController.Player, of side: Disk, animated: Bool) {
        playerControls[side.index].selectedSegmentIndex = player.index
    }
    
    func updatePlayerActivityInidicatorVisibility(_ isVisible: Bool, of side: Disk, animated: Bool) {
        if isVisible {
            playerActivityIndicators[side.index].startAnimating()
        } else {
            playerActivityIndicators[side.index].stopAnimating()
        }
    }
    
    func confirmToResetGame(completion: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion(true) })
        present(alertController, animated: true)
    }
    
    func alertPass(of side: Disk, completion: @escaping () -> Void) {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in completion() })
        present(alertController, animated: true)
    }
    
    func updateDisk(_ disk: Disk?, atX x: Int, y: Int, animated isAnimated: Bool, completion: @escaping () -> Void) -> Canceller {
        boardView.setDisk(disk, atX: x, y: y, animated: isAnimated) { _ in completion() }
        return Canceller {}
    }
}

extension ViewController: GameControllerStrategyDelegate {
    func move(for board: Board, of side: Disk, handler: @escaping (Int, Int) -> Void) -> Canceller {
        CleanReversiAI.move(for: board, of: side) { x, y in handler(x, y) }
    }
}

extension ViewController: GameSaverDelegate {
    private var url: URL {
        URL(fileURLWithPath: (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game"))
    }
    
    func writeData(_ data: Data) throws {
        try data.write(to: url, options: .atomic)
    }
    
    func readData() throws -> Data {
        try Data(contentsOf: url)
    }
}

// MARK: File-private extensions

extension Disk {
    fileprivate init(index: Int) {
        self = Disk.sides.first(where: { $0.index == index })!
    }

    fileprivate var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}

extension GameController.Player {
    fileprivate init(index: Int) {
        self = GameController.Player.values.first(where: { $0.index == index })!
    }
    
    fileprivate var index: Int {
        switch self {
        case .manual: return 0
        case .computer: return 1
        }
    }
    
    fileprivate static var values: [Self] { [.manual, .computer] }
}
