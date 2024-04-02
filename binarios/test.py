import numpy as np
import matplotlib.pyplot as plt

# Define the function
def f(x):
    return 1 / x

# Generate x values
x = np.linspace(-10, 10, 400)

# Generate y values
y = f(x)

# Plot the function
plt.figure(figsize=(8, 6))
plt.plot(x, y, label='$f(x) = \\frac{1}{x}$', color='blue')

# Plot vertical asymptote
plt.axvline(x=0, color='red', linestyle='--', label='Vertical Asymptote ($x = 0$)')

# Set plot labels and title
plt.xlabel('x')
plt.ylabel('f(x)')
plt.title('Graph of $f(x) = \\frac{1}{x}$')
plt.grid(True)
plt.legend()

# Show plot
plt.ylim(-10, 10)  # Limit the y-axis to better visualize the graph
plt.show()
