import SwiftUI
import UIKit
import PiyoCore

/// フリー素材（Microsoft Fluent Emoji, MIT License）から描き出したイラスト。
///
/// 名前は `Assets.xcassets/Art/art.<key>.imageset` と一致する。
/// 追加するときは `Tools/fetch_art_assets.py` の `MANIFEST` に足して実行する。
/// `Tools/art_asset_check.py` が、ここで使う名前と画像の有無を突き合わせる。
struct ArtAsset: Hashable, Sendable {
    let name: String

    init(_ key: String) {
        name = "art.\(key)"
    }

    /// 画像がバンドルに入っているか。無ければ呼び出し側が文字などで代替する。
    var exists: Bool {
        UIImage(named: name) != nil
    }

    // なかま
    static let chick = ArtAsset("chick")
    static let bear = ArtAsset("bear")
    static let cat = ArtAsset("cat")
    static let rabbit = ArtAsset("rabbit")
    static let penguin = ArtAsset("penguin")
    static let trex = ArtAsset("trex")

    // きせかえ
    static let cap = ArtAsset("cap")
    static let ribbon = ArtAsset("ribbon")
    static let crown = ArtAsset("crown")
    static let glasses = ArtAsset("glasses")
    static let scarf = ArtAsset("scarf")

    // おさら・はいけい・スタンプ
    static let plate = ArtAsset("plate")
    static let cherryBlossom = ArtAsset("cherry_blossom")
    static let star = ArtAsset("star")
    static let rainbow = ArtAsset("rainbow")
    static let sunCloud = ArtAsset("sun_cloud")
    static let tree = ArtAsset("tree")
    static let wave = ArtAsset("wave")
    static let planet = ArtAsset("planet")
    static let rocket = ArtAsset("rocket")
    static let moon = ArtAsset("moon")
    static let sun = ArtAsset("sun")
    static let snowflake = ArtAsset("snowflake")
    static let glowingStar = ArtAsset("glowing_star")
    static let sparklingHeart = ArtAsset("sparkling_heart")
    static let medal = ArtAsset("medal")
    static let trophy = ArtAsset("trophy")

    // ごほうび・演出
    static let gift = ArtAsset("gift")
    static let sparkles = ArtAsset("sparkles")
    static let sparkle = ArtAsset("sparkle")
    static let partyPopper = ArtAsset("party_popper")
    static let confettiBall = ArtAsset("confetti_ball")
    static let balloon = ArtAsset("balloon")
    static let hundred = ArtAsset("hundred")
    static let thoughtBalloon = ArtAsset("thought_balloon")
    static let zzz = ArtAsset("zzz")
    static let question = ArtAsset("question")
    static let twoHearts = ArtAsset("two_hearts")
    static let musicalNotes = ArtAsset("musical_notes")
    static let ear = ArtAsset("ear")

    // たべもの
    static let riceBall = ArtAsset("rice_ball")
    static let pancakes = ArtAsset("pancakes")
    static let fish = ArtAsset("fish")
    static let carrot = ArtAsset("carrot")
    static let pot = ArtAsset("pot")
    static let rice = ArtAsset("rice")
    static let bread = ArtAsset("bread")
    static let watermelon = ArtAsset("watermelon")
    static let eggplant = ArtAsset("eggplant")
    static let tangerine = ArtAsset("tangerine")
    static let peach = ArtAsset("peach")
    static let broccoli = ArtAsset("broccoli")
    static let apple = ArtAsset("apple")
    static let iceCream = ArtAsset("ice_cream")
    static let shortcake = ArtAsset("shortcake")
    static let cheese = ArtAsset("cheese")
    static let noodle = ArtAsset("noodle")
    static let milk = ArtAsset("milk")
    static let lemon = ArtAsset("lemon")
    static let tomato = ArtAsset("tomato")
    static let riceCracker = ArtAsset("rice_cracker")
    static let egg = ArtAsset("egg")
    static let grapes = ArtAsset("grapes")
    static let juice = ArtAsset("juice")
    static let candy = ArtAsset("candy")
    static let ice = ArtAsset("ice")
    static let shrimp = ArtAsset("shrimp")
    static let beans = ArtAsset("beans")

    // どうぶつ・むし
    static let duck = ArtAsset("duck")
    static let dog = ArtAsset("dog")
    static let horse = ArtAsset("horse")
    static let giraffe = ArtAsset("giraffe")
    static let bug = ArtAsset("bug")
    static let zebra = ArtAsset("zebra")
    static let butterfly = ArtAsset("butterfly")
    static let snake = ArtAsset("snake")
    static let ladyBeetle = ArtAsset("lady_beetle")
    static let lion = ArtAsset("lion")
    static let crocodile = ArtAsset("crocodile")
    static let turtle = ArtAsset("turtle")
    static let koala = ArtAsset("koala")
    static let chicken = ArtAsset("chicken")
    static let octopus = ArtAsset("octopus")
    static let bird = ArtAsset("bird")
    static let pig = ArtAsset("pig")
    static let teddy = ArtAsset("teddy")
    static let cricket = ArtAsset("cricket")
    static let honeybee = ArtAsset("honeybee")
    static let snail = ArtAsset("snail")
    static let frog = ArtAsset("frog")
    static let sunflower = ArtAsset("sunflower")

    // ひと
    static let woman = ArtAsset("woman")
    static let man = ArtAsset("man")
    static let princess = ArtAsset("princess")
    static let nose = ArtAsset("nose")
    static let child = ArtAsset("child")

    // もの
    static let pencil = ArtAsset("pencil")
    static let umbrella = ArtAsset("umbrella")
    static let sled = ArtAsset("sled")
    static let drum = ArtAsset("drum")
    static let gloves = ArtAsset("gloves")
    static let clock = ArtAsset("clock")
    static let bus = ArtAsset("bus")
    static let tulip = ArtAsset("tulip")
    static let airplane = ArtAsset("airplane")
    static let ship = ArtAsset("ship")
    static let tshirt = ArtAsset("tshirt")
    static let house = ArtAsset("house")
    static let locomotive = ArtAsset("locomotive")
    static let candle = ArtAsset("candle")
    static let runningShoe = ArtAsset("running_shoe")
    static let couch = ArtAsset("couch")
    static let christmasTree = ArtAsset("christmas_tree")
    static let television = ArtAsset("television")
    static let knife = ArtAsset("knife")
    static let notebook = ArtAsset("notebook")
    static let scissors = ArtAsset("scissors")
    static let helicopter = ArtAsset("helicopter")
    static let microphone = ArtAsset("microphone")
    static let sailboat = ArtAsset("sailboat")
    static let magnifier = ArtAsset("magnifier")
    static let key = ArtAsset("key")
    static let package = ArtAsset("package")
    static let soccerBall = ArtAsset("soccer_ball")
    static let topHat = ArtAsset("top_hat")
    static let minibus = ArtAsset("minibus")
    static let droplet = ArtAsset("droplet")
    static let automobile = ArtAsset("automobile")
    static let redHeart = ArtAsset("red_heart")
    static let blueHeart = ArtAsset("blue_heart")
    static let greenHeart = ArtAsset("green_heart")
    static let yellowHeart = ArtAsset("yellow_heart")

    // 画面のアイコン
    static let books = ArtAsset("books")
    static let openBook = ArtAsset("open_book")
    static let bookmarkTabs = ArtAsset("bookmark_tabs")
    static let inputNumbers = ArtAsset("input_numbers")
    static let inputLatin = ArtAsset("input_latin")
    static let globe = ArtAsset("globe")
    static let lightBulb = ArtAsset("light_bulb")
    static let speaker = ArtAsset("speaker")
    static let locked = ArtAsset("locked")
    static let flag = ArtAsset("flag")
    static let stopwatch = ArtAsset("stopwatch")
    static let timer = ArtAsset("timer")
    static let framedPicture = ArtAsset("framed_picture")
    static let crayon = ArtAsset("crayon")
}

/// アプリの中の「なに」を「どの絵」で見せるかの対応表。
enum ArtCatalog {

    static func character(_ style: CharacterArtStyle) -> ArtAsset {
        switch style {
        case .chick: return .chick
        case .bear: return .bear
        case .cat: return .cat
        case .rabbit: return .rabbit
        case .penguin: return .penguin
        case .dinosaur: return .trex
        }
    }

    static func costume(_ artKey: String) -> ArtAsset? {
        switch artKey {
        case "cap": return .cap
        case "ribbon": return .ribbon
        case "crown": return .crown
        case "glasses": return .glasses
        case "scarf": return .scarf
        default: return nil
        }
    }

    /// お皿のふちに散らす模様。白いお皿は模様なし。
    static func tablewarePattern(_ artKey: String) -> ArtAsset? {
        switch artKey {
        case "flower": return .cherryBlossom
        case "star": return .star
        case "rainbow": return .rainbow
        default: return nil
        }
    }

    static func background(_ artKey: String) -> ArtAsset {
        switch artKey {
        case "park": return .tree
        case "sea": return .wave
        case "space": return .planet
        case "night": return .moon
        default: return .sunCloud
        }
    }

    /// はいけいの空の色（上・下）。
    static func backgroundColors(_ artKey: String) -> [Color] {
        switch artKey {
        case "park": return [Color(red: 0.80, green: 0.94, blue: 1.0), Color(red: 0.74, green: 0.90, blue: 0.62)]
        case "sea": return [Color(red: 0.78, green: 0.93, blue: 1.0), Color(red: 0.30, green: 0.68, blue: 0.92)]
        case "space": return [Color(red: 0.16, green: 0.12, blue: 0.36), Color(red: 0.36, green: 0.22, blue: 0.56)]
        case "night": return [Color(red: 0.12, green: 0.18, blue: 0.40), Color(red: 0.26, green: 0.36, blue: 0.62)]
        default: return [Color(red: 0.66, green: 0.86, blue: 1.0), Color(red: 0.88, green: 0.96, blue: 1.0)]
        }
    }

    static func badge(_ artKey: String) -> ArtAsset {
        switch artKey {
        case "grasshopper": return .cricket
        case "butterfly": return .butterfly
        case "ladybug": return .ladyBeetle
        case "snail": return .snail
        case "sunflower": return .sunflower
        case "bee": return .honeybee
        case "frog": return .frog
        case "rainbow": return .rainbow
        case "trophy": return .trophy
        default: return .tulip
        }
    }

    /// ごはんタイマーのお皿に乗せるもの。キャラクターの好物や「ごはん」から引く。
    static func food(named name: String) -> ArtAsset {
        switch name {
        case "おにぎり": return .riceBall
        case "パンケーキ": return .pancakes
        case "おさかな": return .fish
        case "にんじん": return .carrot
        case "やさいスープ": return .pot
        case "パン": return .bread
        default: return .rice
        }
    }

    static func subject(_ subject: Subject) -> ArtAsset {
        switch subject {
        case .clock: return .clock
        case .hiragana: return .openBook
        case .katakana: return .bookmarkTabs
        case .number: return .inputNumbers
        case .alphabet: return .inputLatin
        case .englishWord: return .globe
        }
    }

    static func countable(_ kind: CountableObject) -> ArtAsset {
        switch kind {
        case .apple: return .apple
        case .star: return .star
        case .fish: return .fish
        case .ball: return .soccerBall
        case .candy: return .candy
        case .flower: return .tulip
        case .car: return .automobile
        case .bear: return .teddy
        }
    }

    /// かなの例語（ひらがな）。かなカードの illustration キーで引く。
    static let kana: [String: ArtAsset] = [
        "duck": .duck,
        "dog": .dog,
        "horse": .horse,
        "pencil": .pencil,
        "riceball": .riceBall,
        "umbrella": .umbrella,
        "giraffe": .giraffe,
        "bear": .bear,
        "caterpillar": .bug,
        "ice": .ice,
        "fish": .fish,
        "zebra": .zebra,
        "watermelon": .watermelon,
        "ricecracker": .riceCracker,
        "sled": .sled,
        "drum": .drum,
        "butterfly": .butterfly,
        "moon": .moon,
        "glove": .gloves,
        "clock": .clock,
        "eggplant": .eggplant,
        "carrot": .carrot,
        "teddy": .teddy,
        "cat": .cat,
        "vehicle": .bus,
        "flower": .tulip,
        "airplane": .airplane,
        "ship": .ship,
        "snake": .snake,
        "star": .star,
        "beans": .beans,
        "orange": .tangerine,
        "bug": .ladyBeetle,
        "glasses": .glasses,
        "peach": .peach,
        "vegetable": .broccoli,
        "snow": .snowflake,
        "clothes": .tshirt,
        "lion": .lion,
        "apple": .apple,
        "house": .house,
        "train": .locomotive,
        "candle": .candle,
        "crocodile": .crocodile,
        "bread": .bread
    ]

    /// カタカナの例語は、ひらがなの例語と別の物なので、ことばで引く。
    static let katakanaWords: [String: ArtAsset] = [
        "アイス": .iceCream,
        "イヌ": .dog,
        "ウサギ": .rabbit,
        "エビ": .shrimp,
        "オレンジ": .tangerine,
        "カメ": .turtle,
        "キリン": .giraffe,
        "クツ": .runningShoe,
        "ケーキ": .shortcake,
        "コアラ": .koala,
        "サカナ": .fish,
        "シマウマ": .zebra,
        "スイカ": .watermelon,
        "セミ": .bug,
        "ソファ": .couch,
        "タコ": .octopus,
        "チーズ": .cheese,
        "ツリー": .christmasTree,
        "テレビ": .television,
        "トマト": .tomato,
        "ナイフ": .knife,
        "ニワトリ": .chicken,
        "ヌードル": .noodle,
        "ネコ": .cat,
        "ノート": .notebook,
        "ハサミ": .scissors,
        "ヒコウキ": .airplane,
        "フネ": .ship,
        "ヘリコプター": .helicopter,
        "ホシ": .star,
        "マイク": .microphone,
        "ミルク": .milk,
        "ムシ": .ladyBeetle,
        "メガネ": .glasses,
        "モモ": .peach,
        "ヤサイ": .broccoli,
        "ユキ": .snowflake,
        "ヨット": .sailboat,
        "ライオン": .lion,
        "リンゴ": .apple,
        "ルーペ": .magnifier,
        "レモン": .lemon,
        "ロケット": .rocket,
        "ワニ": .crocodile,
        "パン": .bread
    ]

    /// 英単語。英単語カードの illustration キーで引く。
    static let english: [String: ArtAsset] = [
        "apple": .apple,
        "dog": .dog,
        "cat": .cat,
        "car": .automobile,
        "sun": .sun,
        "moon": .moon,
        "red": .redHeart,
        "blue": .blueHeart,
        "green": .greenHeart,
        "yellow": .yellowHeart,
        "mom": .woman,
        "dad": .man,
        "lion": .lion,
        "fish": .fish,
        "bird": .bird,
        "egg": .egg,
        "milk": .milk,
        "ball": .soccerBall,
        "tree": .tree,
        "star": .star,
        "grape": .grapes,
        "hat": .topHat,
        "ice": .ice,
        "juice": .juice,
        "key": .key,
        "nose": .nose,
        "orange": .tangerine,
        "pig": .pig,
        "queen": .princess,
        "umbrella": .umbrella,
        "van": .minibus,
        "water": .droplet,
        "box": .package,
        "zebra": .zebra
    ]

    /// かなカードの絵。カタカナのときはカタカナの例語で引き、無ければひらがなの絵。
    static func kanaWord(card: KanaCard, subject: Subject) -> ArtAsset? {
        if subject == .katakana, let asset = katakanaWords[card.katakanaWord] {
            return asset
        }
        return kana[card.illustration]
    }
}

/// イラストをそのまま置く。縦横比を保って枠に収める。
struct ArtImage: View {
    var asset: ArtAsset
    var size: CGFloat

    var body: some View {
        Image(asset.name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 動きの量の全体設定。
///
/// UI テスト（`-uiTestMode 1`）では動きを止める。
/// 「視差効果を減らす」が有効な端末でも止める。
enum PiyoMotion {
    /// 起動引数で決まる値。`AppEnvironmentFactory` が起動時に入れる（以後は読むだけ）。
    static var isReducedByLaunchArguments = false

    static func isReduced(accessibilityReduceMotion: Bool) -> Bool {
        isReducedByLaunchArguments || accessibilityReduceMotion
    }
}
