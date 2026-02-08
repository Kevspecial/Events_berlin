# Frontend Implementation Guide

## Project Overview

**Style:** Modern, artistic, editorial/magazine layout
**Framework:** React.js / Next.js
**Styling:** Tailwind CSS with custom configuration
**Animations:** Framer Motion
**Icons:** Lucide React or custom SVG

**Design Principles:**
- Embrace asymmetry and creative layouts
- Use white space as a design element
- Prioritize typography as visual art
- Create overlapping and layered elements
- Break traditional grid constraints for artistic effect

## Design System

### Color Palette

Create CSS custom properties in your main stylesheet:

```css
:root {
  --color-black: #000000;
  --color-white: #FFFFFF;
  --color-gray-light: #F0F0F0;
  --color-red: #FF0000;
}
```

**Usage:**
- Primary text: `--color-black`
- Backgrounds: `--color-white`
- Subtle backgrounds/borders: `--color-gray-light`
- Optional highlights: `--color-red`

### Typography

**Font Family:** Inter (Google Fonts)

Import in your CSS:
```css
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@100;400;800;900&display=swap');

body {
  font-family: 'Inter', sans-serif;
}
```

**Typography Scale:**

| Element | Size | Weight | Letter-spacing | Usage |
|---------|------|--------|-----------------|-------|
| h1 | 5rem (80px) | 900 | -0.02em | Display headings |
| h2 | 3rem (48px) | 800 | -0.02em | Section headings |
| h3 | 1.5rem (24px) | 800 | -0.02em | Card headings |
| body | 1rem (16px) | 400 | 0 | Paragraph text |
| small | 0.875rem (14px) | 400 | 0 | Captions |

**Typography Features:**
- Apply tight letter-spacing: `-0.02em` to `-0.05em` on headings
- Use CSS transforms for text rotation where needed
- Allow text overlap and layering in asymmetric sections
- Use ALL CAPS for specific headings as per design
- Create utility classes for these effects:

```css
.heading-display { font-size: 5rem; font-weight: 900; letter-spacing: -0.02em; }
.heading-section { font-size: 3rem; font-weight: 800; letter-spacing: -0.02em; }
.heading-card { font-size: 1.5rem; font-weight: 800; letter-spacing: -0.02em; }
.text-rotated { transform: rotate(-2deg); }
.text-uppercase { text-transform: uppercase; }
.text-tight { letter-spacing: -0.05em; }
```

## Page Layout Implementation

### 1. Header/Navigation Component

**Location:** Fixed at top of viewport

**Structure:**
```jsx
<header className="fixed top-0 w-full bg-white z-50 border-b border-gray-200">
  <nav className="flex items-center justify-between px-8 py-4">
    {/* Logo */}
    <div className="text-3xl font-black">EventLab</div>
    
    {/* Desktop Navigation */}
    <div className="hidden md:flex gap-8 items-center">
      <a href="#" className="hover:underline">Actually Event</a>
      <div className="bg-black text-white rounded-full px-3 py-1 text-sm">3</div>
      <a href="#" className="hover:underline">Buy Ticket</a>
      <a href="#" className="hover:underline">Our Mission</a>
    </div>
    
    {/* Mobile Hamburger */}
    <button className="md:hidden">☰</button>
  </nav>
</header>
```

**Features:**
- Sticky on scroll
- Minimalist design
- Subtle hover effects (underline on nav items)
- Badge for notifications (number "3")
- Mobile hamburger menu that slides open on click

### 2. Hero/Gallery Section

**Structure:**
```jsx
<section className="py-20 px-8">
  <div className="max-w-7xl mx-auto">
    {/* Use CSS Grid with asymmetric layout */}
    <div className="grid grid-cols-12 gap-8 items-start">
      {/* Main heading - spans multiple columns */}
      <div className="col-span-8">
        <h1 className="heading-display text-9xl font-black leading-tight">
          Gallery
        </h1>
      </div>
      
      {/* Subheading with rotation effect */}
      <div className="col-span-4 text-text-rotated">
        <h2 className="text-3xl font-black uppercase">
          We Create<br />The Next Level<br />Creation
        </h2>
      </div>
    </div>
  </div>
</section>
```

**Features:**
- Asymmetric grid layout
- Large display typography
- Text may be rotated/angled using `text-rotated` class
- High contrast black on white
- Use negative space intentionally

### 3. Mission/Content Section

**Structure:**
```jsx
<section className="py-20 px-8 bg-white">
  <div className="max-w-7xl mx-auto">
    <div className="grid grid-cols-1 md:grid-cols-2 gap-12">
      {/* Left Column */}
      <div>
        <h2 className="text-rotated text-5xl font-black mb-8">NewEvent</h2>
        
        <p className="text-tight text-base font-bold mb-6">
          ABOUTOURMISSIONOURAGENCYCREATINGANDINVITESTHEQUALITY
          EVENTMEETING,FESTIVAL,MUSEUMSCULPTURE
          ONTHEUNITEDSTATES-SINCE@1982.ANEW
          VISIONOFTHESHOWCASE.
        </p>
        
        <p className="text-tight text-base font-bold">
          WECREATEINSPIRINGEVENTS COMBINEDWITHARTEFFECTIVE
          FORMOFINVOLVINGPEOPLEINPRODUCTPROMOTIONWITHMODERN
          WEBSITE.
        </p>
        
        <p className="text-xs mt-12 text-gray-600">Created in/S</p>
      </div>
      
      {/* Right Column - Event Cards */}
      <div className="space-y-8">
        <EventCard 
          title="Museum"
          subtitle="Opening New Collect"
          category="art"
          imageUrl="/images/museum.jpg"
        />
        
        <EventCard 
          title="Sculpture"
          subtitle="Upcoming Event"
          category="art"
          imageUrl="/images/sculpture.jpg"
        />
      </div>
    </div>
  </div>
</section>
```

**Event Card Component:**
```jsx
export function EventCard({ title, subtitle, category, imageUrl, isFeatured = false }) {
  return (
    <div className="group cursor-pointer">
      <div className="relative overflow-hidden h-64 bg-gray-100 mb-4">
        <img 
          src={imageUrl} 
          alt={title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
        <div className="absolute inset-0 bg-black/10 group-hover:bg-black/20 transition-colors" />
      </div>
      
      <h3 className="text-3xl font-black uppercase mb-2 group-hover:underline">
        {title}
      </h3>
      <p className="text-lg font-bold uppercase text-gray-600">
        {subtitle}
      </p>
    </div>
  );
}
```

**Features:**
- Two-column desktop layout, stacked on mobile
- Event cards with hover effects (image zoom, underline)
- Tight letter-spacing text in mission statement
- Rotated heading on left side
- Credit text at bottom

### 4. Ticket/Footer Section

**Structure:**
```jsx
<section className="bg-white border-t border-gray-200">
  <div className="max-w-7xl mx-auto px-8 py-16">
    <div className="grid grid-cols-1 md:grid-cols-2 gap-12">
      {/* Left Side */}
      <div>
        <h2 className="text-7xl font-black mb-8">Buy<br />Ticket</h2>
        
        <nav className="space-y-3 mb-12">
          <a href="#" className="block text-lg font-bold uppercase hover:underline">
            Homepage
          </a>
          <a href="#" className="block text-lg font-bold uppercase hover:underline">
            Events
          </a>
          <a href="#" className="block text-lg font-bold uppercase hover:underline">
            About Us
          </a>
          <a href="#" className="block text-lg font-bold uppercase hover:underline">
            Buy Ticket
          </a>
          <a href="#" className="block text-lg font-bold uppercase hover:underline">
            Privacy Policy
          </a>
        </nav>
        
        <p className="text-base font-bold text-gray-700 max-w-sm">
          CREATING INVITATIONS TO THE EVENT AND PROVIDING A VALUABLE SOURCE OF KNOWLEDGE.
        </p>
      </div>
      
      {/* Right Side */}
      <div className="flex flex-col justify-between">
        <div></div>
        
        <p className="text-sm font-bold text-gray-600">
          COPYRIGHT 2022 kancodes PLATFORM. ALL RIGHTS RESERVED
        </p>
      </div>
    </div>
  </div>
</section>
```

**Features:**
- Asymmetric split layout
- Large "BUY TICKET" heading on left
- Vertical navigation links with hover effects
- Copyright text on right
- Space for future social media links

## Reusable Components

### Header Component

**File:** `components/Navbar.tsx`

Props:
- `navItems: { label: string; href: string; }[]`
- `notification?: number`
- `onMobileMenuToggle?: () => void`

Behavior:
- Fixed position, sticky on scroll
- Shows hamburger menu on mobile (breakpoint < 768px)
- Notification badge displays count
- Hover effects on nav items

### Event Card Component

**File:** `components/EventCard.tsx`

Props:
- `title: string` (e.g., "Museum")
- `subtitle: string` (e.g., "OPENING NEW COLLECT")
- `category: string` (e.g., "art", "sculpture")
- `imageUrl: string`
- `isFeatured?: boolean`

Features:
- Hover effects: image zoom (scale-105), overlay darkens
- Border and shadow on hover
- Smooth transition animations
- Responsive image sizing

### Text Block Component

Props:
- `content: string`
- `isRotated?: boolean`
- `isTight?: boolean` (tight letter-spacing)
- `isUppercase?: boolean`
- `className?: string`


## Responsive Design Implementation

**Tailwind CSS Breakpoints:**

| Breakpoint | Size | Implementation |
|------------|------|-----------------|
| Mobile | < 640px | `sm:` prefix |
| Tablet | 640px - 1024px | `md:` prefix |
| Desktop | > 1024px | `lg:` prefix |

**Implementation Strategy:**

**Mobile (< 640px):**
```css
/* Hide desktop navigation, show hamburger */
.desktop-nav { @apply hidden; }
.mobile-menu { @apply block; }

/* Stack sections vertically */
.grid-cols-2 { @apply grid-cols-1; }

/* Adjust font sizes */
h1 { @apply text-4xl; }
h2 { @apply text-2xl; }
```

**Tablet (640px - 1024px):**
```css
/* Show desktop nav */
.desktop-nav { @apply flex; }
.mobile-menu { @apply hidden; }

/* Two-column layouts */
.grid-cols-2 { @apply grid-cols-2; }

/* Adjusted spacing */
.px-8 { @apply px-6; }
.py-20 { @apply py-16; }
```

**Desktop (> 1024px):**
- Full creative asymmetric layouts
- All interactive features enabled
- Overlapping elements and effects
- Maximum whitespace utilization

**Key CSS Guidelines:**
- Use Tailwind's responsive prefixes consistently
- Test at 375px, 768px, 1024px, 1440px viewport widths
- Use `max-w-7xl` for content containers
- Adjust grid gaps based on breakpoint

## Interactive Features Implementation

### Navigation Hover States

```css
a {
  @apply transition-all duration-200;
  
  &:hover {
    @apply underline;
  }
  
  &:focus {
    @apply outline-2 outline-offset-2 outline-black;
  }
}
```

### Event Card Interactions

Using Framer Motion:

```jsx
<motion.div 
  whileHover={{ scale: 1.02 }}
  whileTap={{ scale: 0.98 }}
  transition={{ duration: 0.2 }}
>
  {/* Card content */}
</motion.div>
```

### Mobile Menu Animation

```jsx
const [isOpen, setIsOpen] = useState(false);

<motion.div
  initial={false}
  animate={isOpen ? "open" : "closed"}
  variants={{
    open: { x: 0, opacity: 1 },
    closed: { x: "-100%", opacity: 0 }
  }}
  transition={{ duration: 0.3 }}
>
  {/* Mobile nav */}
</motion.div>
```

### Scroll Animations

Use Framer Motion's `whileInView`:

```jsx
<motion.section
  initial={{ opacity: 0 }}
  whileInView={{ opacity: 1 }}
  transition={{ duration: 0.6 }}
  viewport={{ once: true }}
>
  {/* Section content */}
</motion.section>
```

**Features to Implement:**
- Smooth page transition between sections
- Fade-in animations for below-the-fold content
- Subtle parallax effects on scroll (optional)
- Image lazy loading with blur-up effect


### Global Styles

## Accessibility Requirements

### Semantic HTML

Use proper semantic elements:

### Keyboard Navigation

- All interactive elements must be focusable using Tab key
- Focus indicators should be visible (outline-black typically)
- Focus order should follow logical reading order
- Escape key should close mobile menu

```jsx
<button
  onClick={toggleMenu}
  onKeyDown={(e) => e.key === 'Escape' && closeMenu()}
  className="focus:outline-2 focus:outline-offset-2 focus:outline-black"
>
  {/* Button content */}
</button>
```

### Color Contrast

- Black text on white: ✅ 21:1 (WCAG AAA)
- Ensure all text meets minimum 4.5:1 contrast ratio
- Don't rely on color alone to convey information

### Focus Indicators

```css
:focus {
  @apply outline-2 outline-offset-2 outline-black;
}

:focus-visible {
  @apply outline-2 outline-offset-2 outline-black;
}
```

### Screen Reader Support

- Add `alt` text to all images
- Use `sr-only` class for screen-reader-only text
- Avoid empty headings or links
- Use proper heading hierarchy (h1 → h2 → h3)

## Asset Requirements

### Logo

- Format: SVG (vector)
- Location: `public/logo.svg`
- Responsive sizing using ViewBox
- Single-color (black) version

### Images

- Location: `public/images/`
- Format: WebP with JPG fallback
- Sizes:
  - Hero: 1440x900px
  - Event cards: 600x400px
  - Thumbnails: 300x200px

**Optimization:**
```jsx
import Image from 'next/image';

<Image
  src="/images/museum.jpg"
  alt="Museum opening event"
  width={600}
  height={400}
  loading="lazy"
/>
```

### Icons

- Source: Lucide React library or custom SVG
- Location: `public/icons/`
- Single color (black)
- Consistent sizing (24px base)


### Fonts

- Inter: Load from Google Fonts
- Self-hosted option: Download `.woff2` files to `public/fonts/`

## Development Guidelines

### Layout Structure

- **Main layouts:** Use CSS Grid for overall page structure
- **Component layouts:** Use Flexbox for internal component layouts
- **Asymmetric grids:** `grid-cols-12` for fine-grained control

```jsx
<div className="grid grid-cols-12 gap-8">
  <div className="col-span-8">Main content</div>
  <div className="col-span-4">Sidebar</div>
</div>
```

### CSS Custom Properties

Define theming variables:

```css
:root {
  --color-primary: #000000;
  --color-background: #FFFFFF;
  --font-display: 5rem;
  --letter-spacing-tight: -0.02em;
  --transition-default: all 0.2s ease;
}
```

### Component States

All interactive elements must have proper states:

```css
/* Default state */
button { /* ... */ }

/* Hover state */
button:hover { @apply underline; }

/* Focus state */
button:focus { @apply outline-2 outline-offset-2 outline-black; }

/* Active state */
button:active { @apply opacity-75; }

/* Disabled state */
button:disabled { @apply opacity-50 cursor-not-allowed; }
```



## Performance Optimization

### Image Optimization

- Use Next.js `Image` component for automatic optimization
- Implement lazy loading for below-the-fold images
- Use `blur` placeholder for better perceived performance

### Core Web Vitals Targets

- **LCP (Largest Contentful Paint):** < 2.5s
- **FID (First Input Delay):** < 100ms
- **CLS (Cumulative Layout Shift):** < 0.1

