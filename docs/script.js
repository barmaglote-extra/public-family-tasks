// Carousel functionality for Family Tasks GitHub Pages

document.addEventListener('DOMContentLoaded', function() {
    const carousel = document.getElementById('carousel');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');
    const indicatorsContainer = document.getElementById('indicators');
    const screenshots = carousel.querySelectorAll('.screenshot');
    
    let currentIndex = 0;
    
    // Create indicators
    function createIndicators() {
        screenshots.forEach((_, index) => {
            const indicator = document.createElement('div');
            indicator.classList.add('indicator');
            if (index === 0) indicator.classList.add('active');
            indicator.addEventListener('click', () => goToSlide(index));
            indicatorsContainer.appendChild(indicator);
        });
    }
    
    // Update carousel display
    function updateCarousel() {
        screenshots.forEach((screenshot, index) => {
            screenshot.classList.remove('active', 'prev', 'next');
            
            if (index === currentIndex) {
                screenshot.classList.add('active');
            } else if (index === (currentIndex - 1 + screenshots.length) % screenshots.length) {
                screenshot.classList.add('prev');
            } else if (index === (currentIndex + 1) % screenshots.length) {
                screenshot.classList.add('next');
            }
        });
        
        // Update indicators
        const indicators = indicatorsContainer.querySelectorAll('.indicator');
        indicators.forEach((indicator, index) => {
            indicator.classList.toggle('active', index === currentIndex);
        });
    }
    
    // Navigate to specific slide
    function goToSlide(index) {
        currentIndex = index;
        updateCarousel();
    }
    
    // Next slide
    function nextSlide() {
        currentIndex = (currentIndex + 1) % screenshots.length;
        updateCarousel();
    }
    
    // Previous slide
    function prevSlide() {
        currentIndex = (currentIndex - 1 + screenshots.length) % screenshots.length;
        updateCarousel();
    }
    
    // Initialize carousel
    if (carousel && prevBtn && nextBtn && indicatorsContainer) {
        createIndicators();
        updateCarousel();
        
        // Event listeners
        prevBtn.addEventListener('click', prevSlide);
        nextBtn.addEventListener('click', nextSlide);
        
        // Keyboard navigation
        document.addEventListener('keydown', function(e) {
            if (e.key === 'ArrowLeft') {
                prevSlide();
            } else if (e.key === 'ArrowRight') {
                nextSlide();
            }
        });
        
        // Auto-advance carousel every 5 seconds
        setInterval(nextSlide, 5000);
    }
});