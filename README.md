Manually copy to a Jupyter data location `jupyter --paths`.

Then change the paths in `kernel.json` to match your machine.


## Design

![Design](http://plantuml.mpcjanssen.nl/png/TOvD2eCm48NtESNGlHUGqeqhSHcNGXbrg85qJ3DHyFRLD6YbTFlUztuS-c0wuv03N0fhY4F3caJCo1T0WK8hzyrKv9bijAgpar8DruCdx2EYwpzCoO6y-p2bKeM6BBj11JbuUaqaGLLHANGEPdHJ2-qaIn9rdSE0t5kwF-MXT0sRMEP0Crg5NJ0p1jgATGc9xuquYqk4jwL3EOPsPazvaia6rTEfTAz8zlh-ccNflRYHXNxkc_Nj6m00)


### IPC

To prevent implementing a lot of the IPC between the kernel main thread and the threads handling client session, I am strongly contemplating to use a tuplespace for IPC. And probably the thread based one from https://fossil.mpcjanssen.nl/tuplespace-threads

Then the design will look like:

![TS Design](http://plantuml.mpcjanssen.nl/png/TP3DgiCW58JtFiMX-xv05zsuaX08c6KsDZbS137Mdz2y_LLZ9H6wTEPpPjG8w-KiZT0URbH9r7xI79sJgxw1S40vCMUcGwjHPQkxEdsy9VvmqeDTFtic-W6kp1YCmbHWDxGP6PlyqZtfOqncEFt1CEtHceDXX7HmlpzZuWESZtmvzqCvppcH4CghRl4Tq7aIXoQ9quA2Eog-1esP9hpW5Tp-rLBF6dpAgFZ8QuxK5uTJI0Px06v24J5xkGcFQJTdzT8YdL5Yp_IfeiXjJNf1h6dTq-QQnw0qM7H1URBWPG5jNkJCZwwBTIfAUljPSb7u3m00)
