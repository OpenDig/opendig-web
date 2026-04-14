// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

console.log('application.js loaded')

const setStarState = (button, isFavorited) => {
  const star = button.querySelector('span')
  if (!star) return

  star.classList.toggle('text-yellow-400', isFavorited)
  star.classList.toggle('text-gray-300', !isFavorited)
  button.dataset.favorited = String(isFavorited)
}

const toggleFavoriteArea = async (button) => {
  const areaKey = button.dataset.areaKey
  const favoriteUrl = button.dataset.favoriteUrl
  const unfavoriteUrl = button.dataset.unfavoriteUrl
  const currentlyFavorited = button.dataset.favorited === 'true'
  const nextState = !currentlyFavorited

  console.log('Toggling favorite:', { areaKey, currentlyFavorited, favoriteUrl, unfavoriteUrl })

  if (!areaKey) {
    console.error('Missing areaKey')
    return
  }

  if (!favoriteUrl || !unfavoriteUrl) {
    console.error('Missing URLs:', { favoriteUrl, unfavoriteUrl })
    return
  }

  setStarState(button, nextState)

  const csrfTokenMeta = document.querySelector('meta[name="csrf-token"]')
  const csrfToken = csrfTokenMeta && csrfTokenMeta.getAttribute('content')

  const requestUrl = new URL(currentlyFavorited ? unfavoriteUrl : favoriteUrl, window.location.origin)
  requestUrl.searchParams.append('area_key', areaKey)

  try {
    console.log('Sending request to:', requestUrl.toString())
    const response = await fetch(requestUrl.toString(), {
      method: currentlyFavorited ? 'DELETE' : 'POST',
      headers: {
        'X-CSRF-Token': csrfToken || ''
      }
    })

    console.log('Response status:', response.status)

    if (!response.ok) {
      console.error('Request failed:', response.statusText)
      setStarState(button, currentlyFavorited)
      return
    }

    window.location.reload()
  } catch (error) {
    console.error('Fetch error:', error)
    setStarState(button, currentlyFavorited)
  }
}

function initFavoriteButtons() {
  console.log('Initializing favorite buttons')
  const buttons = document.querySelectorAll('.favorite-star[data-area-key]')
  console.log('Found ' + buttons.length + ' favorite buttons')
  
  buttons.forEach(button => {
    button.addEventListener('click', (event) => {
      console.log('Button clicked:', button.dataset.areaKey)
      event.preventDefault()
      toggleFavoriteArea(button)
    })
  })
}

// Make function globally available for onclick handlers
window.toggleFavoriteAreaClick = function(event) {
  console.log('toggleFavoriteAreaClick called from onclick')
  if (event) event.preventDefault()
  const button = event?.target?.closest('.favorite-star')
  if (button) {
    toggleFavoriteArea(button)
  }
}

// Initialize on DOM ready and Turbo navigation
document.addEventListener('DOMContentLoaded', initFavoriteButtons)
document.addEventListener('turbo:load', initFavoriteButtons)

// Also try document ready with immediate call
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initFavoriteButtons)
} else {
  initFavoriteButtons()
}

