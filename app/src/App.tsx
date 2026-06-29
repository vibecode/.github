import { useState, useEffect, useCallback } from 'react'
import './App.css'

const SUGGESTIONS = [
  'A fitness tracker with daily goals',
  'A recipe app with shopping lists',
  'A meditation timer with streaks',
  'A budget tracker for couples',
]

type AppPreview = {
  name: string
  tagline: string
  items: { icon: string; label: string }[]
  buttonText: string
}

const PRESETS: Record<string, AppPreview> = {
  fitness: {
    name: 'FitFlow',
    tagline: 'Your daily movement companion',
    items: [
      { icon: '🏃', label: '8,432 steps today' },
      { icon: '🔥', label: '420 cal burned' },
      { icon: '💧', label: '6 of 8 glasses' },
    ],
    buttonText: 'Start Workout',
  },
  recipe: {
    name: 'ChefMate',
    tagline: 'Cook smarter, shop easier',
    items: [
      { icon: '🥗', label: 'Mediterranean Bowl' },
      { icon: '🛒', label: '12 items on list' },
      { icon: '⭐', label: '24 saved recipes' },
    ],
    buttonText: 'View Recipes',
  },
  meditation: {
    name: 'CalmSpace',
    tagline: 'Find your center daily',
    items: [
      { icon: '🧘', label: '15 min session' },
      { icon: '🔥', label: '21 day streak' },
      { icon: '🌙', label: 'Sleep sounds ready' },
    ],
    buttonText: 'Begin Session',
  },
  budget: {
    name: 'SplitWise',
    tagline: 'Shared finances made simple',
    items: [
      { icon: '💰', label: '$2,340 monthly budget' },
      { icon: '📊', label: '68% spent so far' },
      { icon: '👫', label: '2 accounts linked' },
    ],
    buttonText: 'Add Expense',
  },
  default: {
    name: 'MyApp',
    tagline: 'Built with Vibecode',
    items: [
      { icon: '✨', label: 'Beautiful native UI' },
      { icon: '⚡', label: 'Lightning fast' },
      { icon: '📱', label: 'iOS & Android ready' },
    ],
    buttonText: 'Get Started',
  },
}

function detectPreset(prompt: string): AppPreview {
  const lower = prompt.toLowerCase()
  if (lower.includes('fit') || lower.includes('workout') || lower.includes('step')) {
    return PRESETS.fitness
  }
  if (lower.includes('recipe') || lower.includes('cook') || lower.includes('food')) {
    return PRESETS.recipe
  }
  if (lower.includes('meditat') || lower.includes('calm') || lower.includes('mindful')) {
    return PRESETS.meditation
  }
  if (lower.includes('budget') || lower.includes('money') || lower.includes('expense')) {
    return PRESETS.budget
  }
  return {
    ...PRESETS.default,
    name: prompt.split(' ').slice(0, 2).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('') || 'MyApp',
    tagline: prompt.slice(0, 40) || PRESETS.default.tagline,
  }
}

function PhonePreview({ preview }: { preview: AppPreview }) {
  return (
    <div className="phone-mockup">
      <div className="phone-frame">
        <div className="phone-notch" />
        <div className="phone-screen" key={preview.name}>
          <div className="phone-header">
            <span className="phone-app-name">{preview.name}</span>
            <div className="phone-avatar" />
          </div>
          <div className="phone-card">
            <h3>Welcome back</h3>
            <p>{preview.tagline}</p>
          </div>
          <div className="phone-list">
            {preview.items.map((item) => (
              <div className="phone-list-item" key={item.label}>
                <span className="phone-list-icon">{item.icon}</span>
                <span>{item.label}</span>
              </div>
            ))}
          </div>
          <div className="phone-btn">{preview.buttonText}</div>
        </div>
      </div>
    </div>
  )
}

function App() {
  const [prompt, setPrompt] = useState('')
  const [preview, setPreview] = useState<AppPreview>(PRESETS.default)
  const [building, setBuilding] = useState(false)

  const build = useCallback((text: string) => {
    if (!text.trim()) return
    setBuilding(true)
    setTimeout(() => {
      setPreview(detectPreset(text))
      setBuilding(false)
    }, 1200)
  }, [])

  useEffect(() => {
    const timer = setTimeout(() => {
      if (prompt.trim()) build(prompt)
    }, 600)
    return () => clearTimeout(timer)
  }, [prompt, build])

  return (
    <div className="app">
      <div className="bg-glow" />

      <header className="header">
        <div className="logo">
          <div className="logo-icon">V</div>
          Vibecode
        </div>
        <nav className="nav">
          <a href="#features">Features</a>
          <a href="#builder">Try it</a>
          <a href="https://www.vibecodeapp.com" target="_blank" rel="noopener noreferrer">
            Download
          </a>
        </nav>
        <a
          className="btn btn-primary"
          href="https://www.vibecodeapp.com"
          target="_blank"
          rel="noopener noreferrer"
        >
          Get the App
        </a>
      </header>

      <section className="hero">
        <div className="hero-content">
          <div className="badge">
            <span className="badge-dot" />
            Now available on iOS
          </div>
          <h1>
            Build native apps
            <br />
            <span className="gradient-text">at the speed of thought</span>
          </h1>
          <p>
            Vibecode is the first mobile app that builds mobile apps. Describe what
            you want — get a fully-native app in minutes.
          </p>
          <div className="hero-actions">
            <a
              className="btn btn-primary btn-lg"
              href="https://www.vibecodeapp.com"
              target="_blank"
              rel="noopener noreferrer"
            >
              Download Vibecode
            </a>
            <a className="btn btn-secondary btn-lg" href="#builder">
              Try the demo
            </a>
          </div>
          <div className="hero-stats">
            <div className="stat">
              <span className="stat-value">10x</span>
              <span className="stat-label">Faster than coding</span>
            </div>
            <div className="stat">
              <span className="stat-value">100%</span>
              <span className="stat-label">Native performance</span>
            </div>
            <div className="stat">
              <span className="stat-value">0</span>
              <span className="stat-label">Lines of code needed</span>
            </div>
          </div>
        </div>
        <PhonePreview preview={preview} />
      </section>

      <section className="builder" id="builder">
        <div className="section-header">
          <h2>See it in action</h2>
          <p>Describe an app idea and watch it come to life</p>
        </div>
        <div className="builder-card">
          <label className="builder-label" htmlFor="prompt">
            What do you want to build?
          </label>
          <textarea
            id="prompt"
            className="builder-input"
            placeholder="e.g. A fitness tracker with daily goals and workout reminders..."
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
          />
          <div className="builder-suggestions">
            {SUGGESTIONS.map((s) => (
              <button
                key={s}
                className="suggestion-chip"
                onClick={() => setPrompt(s)}
                type="button"
              >
                {s}
              </button>
            ))}
          </div>
          {building && (
            <div className="builder-progress">
              <div className="spinner" />
              Building your app...
            </div>
          )}
        </div>
      </section>

      <section className="features" id="features">
        <div className="section-header">
          <h2>Why Vibecode?</h2>
          <p>Everything you need to go from idea to App Store</p>
        </div>
        <div className="features-grid">
          <div className="feature-card">
            <div className="feature-icon">📱</div>
            <h3>Fully Native</h3>
            <p>
              Real Swift and Kotlin apps — not web wrappers. Smooth animations,
              native gestures, and platform-perfect UI.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">⚡</div>
            <h3>Lightning Fast</h3>
            <p>
              Go from a text description to a working prototype in minutes. Iterate
              with natural language, not code.
            </p>
          </div>
          <div className="feature-card">
            <div className="feature-icon">🚀</div>
            <h3>Ship to Stores</h3>
            <p>
              Export production-ready builds for the App Store and Google Play.
              Your app, your brand, ready to launch.
            </p>
          </div>
        </div>
      </section>

      <section className="cta">
        <div className="cta-card">
          <h2>Ready to build your first app?</h2>
          <p>Download Vibecode and turn your ideas into native mobile apps today.</p>
          <a
            className="btn btn-primary btn-lg"
            href="https://www.vibecodeapp.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            Get Vibecode Free
          </a>
        </div>
      </section>

      <footer className="footer">
        <p>© {new Date().getFullYear()} Vibecode. The first mobile app that builds mobile apps.</p>
      </footer>
    </div>
  )
}

export default App
