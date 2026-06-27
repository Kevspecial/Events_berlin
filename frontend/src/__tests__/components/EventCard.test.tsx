import { render, screen } from '@testing-library/react';
import EventCard from '@/components/EventCard';
import type { Event } from '@/types';

jest.mock('framer-motion', () => ({
  motion: {
    div: ({ children, ...props }: React.ComponentProps<'div'>) => <div {...props}>{children}</div>,
  },
}));

jest.mock('next/link', () => ({
  __esModule: true,
  default: ({ children, href }: { children: React.ReactNode; href: string }) => (
    <a href={href}>{children}</a>
  ),
}));

const mockEvent: Event = {
  id: 1,
  name: 'Berlin Tech Meetup',
  description: 'Monthly developer meetup',
  date: '2027-08-15T19:00:00Z',
  location: 'Factory Berlin',
  price: 0,
  capacity: 100,
  private: false,
  creator_id: 1,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
  image_url: undefined,
};

describe('EventCard', () => {
  it('renders event name', () => {
    render(<EventCard event={mockEvent} />);
    expect(screen.getByText('Berlin Tech Meetup')).toBeInTheDocument();
  });

  it('shows FREE for price 0', () => {
    render(<EventCard event={mockEvent} />);
    expect(screen.getByText('FREE')).toBeInTheDocument();
  });

  it('shows location', () => {
    render(<EventCard event={mockEvent} />);
    expect(screen.getByText('Factory Berlin')).toBeInTheDocument();
  });

  it('shows price when non-zero', () => {
    render(<EventCard event={{ ...mockEvent, price: 29.99 }} />);
    expect(screen.getByText('€29.99')).toBeInTheDocument();
  });

  it('links to event detail page', () => {
    render(<EventCard event={mockEvent} />);
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', '/events/1');
  });
});
