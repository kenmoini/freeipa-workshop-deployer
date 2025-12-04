---
layout: page
title: Blog Posts
permalink: /blog/
---

# Blog Posts

Here you can find all our blog posts, including calls for contribution and project updates.

{% for post in site.posts %}
## [{{ post.title }}]({{ post.url | relative_url }})

{{ post.date | date: "%B %d, %Y" }}

{{ post.excerpt }}

[Read more]({{ post.url | relative_url }})

---
{% endfor %}
