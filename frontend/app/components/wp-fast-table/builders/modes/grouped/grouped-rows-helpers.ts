import {GroupObject} from '../../../../api/api-v3/hal-resources/wp-collection-resource.service';

export function groupIdentifier(group:GroupObject) {
  return `${groupByProperty(group)}-${group.value || 'nullValue'}`;
}

export function groupName(group:GroupObject) {
  let value = group.value;
  if (value === null) {
    return '-';
  } else {
    return value;
  }
}

export function groupByProperty(group:GroupObject):string {
  return group._links!.groupBy.href.split('/').pop()!;
}

/**
 * Get the row group class name for the given group id.
 */
export function groupedRowClassName(groupIndex:number) {
  return `__row-group-${groupIndex}`;
}
