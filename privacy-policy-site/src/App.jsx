import { sections, lastUpdated, contactEmail } from './content.jsx'

function Header() {
  return (
    <header className="site-header">
      <div className="container header-inner">
        <a className="brand" href="#top" aria-label="Resumer — back to top">
          <span className="brand-mark" aria-hidden="true">R</span>
          <span className="brand-name">Resumer</span>
        </a>
        <nav className="header-nav" aria-label="Primary">
          <a href="#policy">Privacy Policy</a>
        </nav>
      </div>
    </header>
  )
}

function Hero() {
  return (
    <section className="hero" id="top">
      <div className="container">
        <span className="hero-eyebrow">Legal · Privacy</span>
        <h1 className="hero-title">
          Privacy <span className="gradient-text">Policy</span>
        </h1>
        <p className="hero-sub">
          How Resumer collects, uses, and protects your information when you
          build truthful, job-tailored resumes with us.
        </p>
        <div className="hero-meta">
          <span className="chip">Effective {lastUpdated}</span>
          <span className="chip">Applies to the Resumer apps &amp; web platform</span>
        </div>
      </div>
    </section>
  )
}

function TableOfContents() {
  return (
    <nav className="toc" aria-label="Table of contents">
      <span className="toc-label">On this page</span>
      <div className="toc-links">
        {sections.map((section) => (
          <a key={section.id} href={`#${section.id}`}>
            {section.title}
          </a>
        ))}
      </div>
    </nav>
  )
}

function Section({ id, icon, title, blocks }) {
  return (
    <section className="policy-section" id={id}>
      <div className="section-heading">
        <span className="section-icon" aria-hidden="true">{icon}</span>
        <h2>{title}</h2>
      </div>
      <div className="prose">
        {blocks.map((block, index) => {
          if (block.type === 'p') return <p key={index}>{block.text}</p>
          if (block.type === 'h') return <h3 key={index}>{block.text}</h3>
          if (block.type === 'ul') {
            return (
              <ul key={index}>
                {block.items.map((item, itemIndex) => (
                  <li key={itemIndex}>{item}</li>
                ))}
              </ul>
            )
          }
          return null
        })}
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="site-footer">
      <div className="container footer-inner">
        <div className="footer-brand">
          <span className="brand-mark" aria-hidden="true">R</span>
          <div>
            <p className="footer-title">Resumer</p>
            <p className="footer-tag">Truthful resumes, tailored to every job.</p>
          </div>
        </div>
        <div className="footer-links">
          <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
          <a href="#top">Back to top ↑</a>
        </div>
      </div>
      <p className="container copyright">
        © {new Date().getFullYear()} Resumer. All rights reserved.
      </p>
    </footer>
  )
}

export default function App() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <div className="container page-body" id="policy">
          <TableOfContents />
          {sections.map((section) => (
            <Section key={section.id} {...section} />
          ))}
        </div>
      </main>
      <Footer />
    </>
  )
}
