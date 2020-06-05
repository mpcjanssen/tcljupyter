Manually copy to a Jupyter data location `jupyter --paths`.

Then change the paths in `kernel.json` to match your machine.


## Design

![Design](http://plantuml.mpcjanssen.nl/png/TOvD2eCm48NtESNGlHUGqeqhSHcNGXbrg85qJ3DHyFRLD6YbTFlUztuS-c0wuv03N0fhY4F3caJCo1T0WK8hzyrKv9bijAgpar8DruCdx2EYwpzCoO6y-p2bKeM6BBj11JbuUaqaGLLHANGEPdHJ2-qaIn9rdSE0t5kwF-MXT0sRMEP0Crg5NJ0p1jgATGc9xuquYqk4jwL3EOPsPazvaia6rTEfTAz8zlh-ccNflRYHXNxkc_Nj6m00)


### IPC

To prevent implementing a lot of the IPC between the kernel main thread and the threads handling client session, I am strongly contemplating to use a tuplespace for IPC. And probably the thread based one from https://fossil.mpcjanssen.nl/tuplespace-threads

Then the design will look like:

![TS Design](https://plantuml.mpcjanssen.nl/png/TP2nZiCW44HxlcALFZ-G8WsLpx9a2PTkYBqw8I5CMB3EVt-02R8jfMJcCJDWfVDgKbOQ3pUk5He_6e54QZ4ta0HSC7jaMdG6TRRQizF5M_8NHzExvM_BHDV3cHc2rKZeLdIZ-Gbsy-WoELngoeJHx9io8_WNfZ4nnkvCmrWBz_ip9Zw0VEJBkUlBUSg9Z75HTOVlWEHPt9iamGiAj5Ty31upRNZ1Az3sqLBF4dpAgFWWQeuo9qTmI4Rp05obPdBoQfKUqsxHr4kp8glbbkb3HP6lDUa5iURg7ZRNl0PAWqCAshCPJmluvKLaltITh4DHqg-VfMQD_m00)
