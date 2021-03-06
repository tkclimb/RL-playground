import TensorFlow
import Python


public class Taxi : Env{

    enum Action: Int {
        case up = 0, right, down, left, pickUp, dropOff
    }
    typealias State = Int
    typealias Reward = Float
  
    public var α: Float, ε: Float, γ: Float, εDecay: Float
    public var Q: Tensor<Float>
  
    init(_ name: String,
         numEpisodes: Int = 3000,
         α: Float = 0.01,
         ε: Float = 0.3,
         γ: Float = 0.95,
         εDecay: Float = 0.00005,
         enableRender: Bool = false,
         useSaved: Optional<String> = nil) 
    {
        let gym = Python.import("gym")
        let env = gym.make("Taxi-v3")
  
        self.α = α
        self.ε = ε
        self.γ = γ
        self.εDecay = εDecay
        let numStates = Int(env.observation_space.n)!
        let numActions = Int(env.action_space.n)!
        let shape = TensorShape([numStates, numActions])

        if useSaved == nil {
            Q = Tensor<Float>(repeating: 0, shape: shape)
        } else { 
            let path = useSaved!
            Q = loadTensor(path: path)
            print("loaded a tensor from:", path)
        }

        super.init(name, env, numEpisodes, numStates, numActions, enableRender: enableRender, useSaved: useSaved)
    }

    private func εGreedy(_ s: State, _ ε: Float = 0.1) -> Action {
        if Float.random(in: 0...1) < ε {
            return random(s)
        } 
        return greedy(s)
    }
  
    private func greedy(_ s: State) -> Action {
        // just return the action having highest score
        let i = Int(Q[s].argmax().scalarized())
        return Action(rawValue: i)!
    }

    private func random(_ s: State) -> Action {
        let a = Int.random(in: 0...numActions-1)
        return Action(rawValue: a)!
    }
  
    private func update(_ s: State, _ a: Action, _ r: Reward, _ s_next: State) {
        // Q-learning update the state-action value, which
        // is just the max Q value for the next state
        let u = (1 - α) * Q[s][a.rawValue] + α
        let v = α * (r + γ * Q[s_next].max())
        Q[s][a.rawValue] = u + v
    }
  
    private func step(env: PythonObject, a: Action) -> (State, Reward, Bool, PythonObject) {
        let (s, r, done, info) = env.step(a.rawValue).tuple4
        return (Int(s)!, Float(r)!, Bool(done)!, info)
    }
  
    public func play() {
        // var gameRewards: [Reward] = []
        var ε = self.ε
    
        for ep in 0..<numEpisodes {
            var s = Int(env.reset())!
            var rTotal: Reward = 0
            if ε > 0.01 {
                ε -= εDecay
            } 
    
            while true {
                let a = εGreedy(s, ε)
                let (s_next, r, done, _) = step(env: env, a: a)

                if enableRender && ep > 1000 {
                    print("action: \(a), state: \(s), next_state: \(s_next), reward: \(r), done: \(done)")
                    // print(Q[s])
                    env.render()
                    usleep(100000)
                }

                update(s, a, r, s_next)
    
                if(done) { break }
                s = s_next
                rTotal += r
            }

            // gameRewards.append(rTotal)
            if ep % 100 == 0 {
                print("episode: \(ep), total_reward: \(rTotal), ε: \(ε)")
            }
        }

        saveTensor(Q, name: name)
        print("saved a tensor in: \(name).npy")
    }
}