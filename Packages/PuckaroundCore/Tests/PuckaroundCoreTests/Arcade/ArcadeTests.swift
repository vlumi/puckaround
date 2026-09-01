import XCTest

@testable import PuckaroundCore

/// The score-attack loop and the hiscore board.
final class ArcadeTests: XCTestCase {
    func testBumpersAndGoalsPayAndFailedStagesCostLives() {
        var run = ScoreAttack(lives: 2)
        run.ingest([.bumperHit(speed: 100), .bumperHit(speed: 50)])
        XCTAssertEqual(run.score, 2 * ScoreAttack.bumperPoints)
        run.ingest([.goal(scorer: .bottom, conceder: .top)])
        XCTAssertEqual(run.score, 2 * ScoreAttack.bumperPoints + ScoreAttack.goalPoints)
        XCTAssertEqual(run.lives, 2, "scoring costs nothing")
        run.ingest([.goal(scorer: .top, conceder: .bottom)])
        XCTAssertEqual(run.lives, 2, "a drain alone isn't the life — the failed stage is")
        run.ingest([.stageFailed])
        XCTAssertEqual(run.lives, 1)
        XCTAssertFalse(run.isOver)
        run.ingest([.stageFailed])
        XCTAssertTrue(run.isOver)
        let final = run
        run.ingest([.bumperHit(speed: 100)])
        XCTAssertEqual(run, final, "a finished run ignores everything after")
    }

    func testBricksPayLikeBumpers() {
        var run = ScoreAttack()
        run.ingest([.brickBroken(speed: 80), .brickBroken(speed: 200), .brickChipped(speed: 90)])
        XCTAssertEqual(run.score, 3 * ScoreAttack.brickPoints, "chips pay like breaks")
    }

    func testTheBoardHoldsTenBestFirst() {
        var board = Hiscores()
        for score in 1...12 {
            _ = board.submit(name: "P\(score)", score: score * 100)
        }
        XCTAssertEqual(board.entries.count, Hiscores.capacity)
        XCTAssertEqual(board.entries.first?.score, 1200)
        XCTAssertEqual(board.entries.last?.score, 300, "the weakest lines fell off")
    }

    func testRanksTiesAndTheDoorman() {
        var board = Hiscores()
        XCTAssertFalse(board.qualifies(0), "a scoreless run never boards")
        XCTAssertEqual(board.submit(name: "Aki", score: 500), 1)
        XCTAssertEqual(board.submit(name: "Boa", score: 700), 1)
        XCTAssertEqual(board.submit(name: "Cai", score: 500), 3, "a tie slots below the holder")
        XCTAssertNil(board.submit(name: "Dee", score: 0))
        // Fill the board, then a score equal to the last line must not board.
        for i in 0..<Hiscores.capacity {
            _ = board.submit(name: "F\(i)", score: 1000 + i)
        }
        let last = board.entries[Hiscores.capacity - 1].score
        XCTAssertFalse(board.qualifies(last), "equal to the last line is not past it")
        XCTAssertTrue(board.qualifies(last + 1))
    }

    func testTheBoardRoundTripsThroughJSON() throws {
        var board = Hiscores()
        _ = board.submit(name: "ヴィレ", score: 800)
        let data = try JSONEncoder().encode(board)
        let back = try JSONDecoder().decode(Hiscores.self, from: data)
        XCTAssertEqual(back, board)
    }
}
