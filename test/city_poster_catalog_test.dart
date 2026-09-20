import 'dart:convert';

import 'package:engelsizclub/data/turkish_cities_data.dart';
import 'package:engelsizclub/features/city_posters/city_poster_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slug matches Python poster filenames', () {
    expect(cityPosterSlug('Gaziantep'), 'gaziantep');
    expect(cityPosterSlug('İstanbul'), 'istanbul');
    expect(cityPosterSlug('Şanlıurfa'), 'sanliurfa');
    expect(cityPosterSlug('Kahramanmaraş'), 'kahramanmaras');
    expect(cityPosterSlug('Çanakkale'), 'canakkale');
  });

  test('merge lists all 81 cities in kCityNames order', () {
    final listing = parseGithubOutputListing(
      jsonEncode([
        {'name': '.gitkeep', 'download_url': null},
        {
          'name': 'adana_muze_gezisi_2026-09-16.jpg',
          'download_url':
              'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/output/adana_muze_gezisi_2026-09-16.jpg',
        },
      ]),
    );
    final items = mergeCityPosters(cities: kCityNames, files: listing);
    expect(items, hasLength(81));
    expect(items.first.city, 'Adana');
    expect(items.first.hasImage, isTrue);
    expect(items.first.date, '2026-09-16');
    expect(items[1].city, 'Adıyaman');
    expect(items[1].hasImage, isFalse);
    expect(items.last.city, 'Ardahan');
    expect(items.where((e) => e.hasImage), hasLength(1));
  });

  test('parseCityPosterIndex maps posters and latest date wins in merge', () {
    final parsed = parseCityPosterIndex(
      jsonEncode({
        'generated_at': '2026-09-16T17:34:00Z',
        'ok': 1,
        'fail': 80,
        'status': 'ok',
        'posters': [
          {
            'city': 'Adana',
            'slug': 'adana',
            'file': 'adana_muze_gezisi_2026-09-01.jpg',
            'date': '2026-09-01',
            'url':
                'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/output/adana_muze_gezisi_2026-09-01.jpg',
          },
          {
            'city': 'Adana',
            'slug': 'adana',
            'file': 'adana_muze_gezisi_2026-09-16.jpg',
            'date': '2026-09-16',
          },
        ],
      }),
    );
    expect(parsed.posters, hasLength(2));
    expect(parsed.run, isNotNull);
    expect(parsed.run!.ok, 1);
    final items = mergeCityPosters(cities: kCityNames, files: parsed.posters);
    expect(items, hasLength(81));
    expect(items.first.city, 'Adana');
    expect(items.first.hasImage, isTrue);
    expect(items.first.date, '2026-09-16');
    expect(items.first.filename, 'adana_muze_gezisi_2026-09-16.jpg');
    expect(items[1].hasImage, isFalse);
    expect(items.last.city, 'Ardahan');
  });

  test('parseLatestWorkflowRun reads conclusion', () {
    final run = parseLatestWorkflowRun(
      jsonEncode({
        'workflow_runs': [
          {
            'conclusion': 'success',
            'html_url':
                'https://github.com/Metehanxpvl/engelsizclub/actions/runs/1',
            'head_sha': 'c26bba90424375b7b851fd740cf005aba889922e',
            'run_number': 2,
            'updated_at': '2026-09-16T15:01:11Z',
          },
        ],
      }),
    );
    expect(run, isNotNull);
    expect(run!.succeeded, isTrue);
    expect(run.runNumber, 2);
    expect(run.headSha, startsWith('c26bba9'));
  });
}
